require 'optparse'
require 'syslog'
require 'io/wait'
require 'senedsa'
require 'socket'
require 'dribbled'

module Dribbled

  class CLI

    include Senedsa

    COMMANDS = %w(show check snap)
    COMPONENTS = %w(resources)
    DEFAULT_CONFIG_FILE = File.join(ENV['HOME'],"/.senedsa/config")

    def initialize(arguments)
      @arguments = arguments
      @whoami = File.basename($PROGRAM_NAME).to_sym

      @global_options = { :debug => false, :drbdadm => 'drbdadm', :xmldump => nil, :procdrbd => '/proc/drbd', :hostname => nil }
      @action_options = { :monitor => :nagios, :mode => :active, :suffix => nil, :directory => '/tmp' }
      @action = nil
    end

    def run
      begin
        parsed_options?

        @log = Dribbled::Logger.instance.log
        @log.level = Log4r::INFO unless @global_options[:debug]
        @global_options[:log] = @log

        config_options?
        arguments_valid?
        options_valid?
        process_options
        process_arguments
        process_command

      rescue => e
        if @global_options[:debug]
          output_message "#{e.message}\n  #{e.backtrace.join("\n  ")}",3
        else
          output_message e.message,3
        end
      end
    end

    protected

    def parsed_options?
      opts = OptionParser.new

      opts.banner = "Usage: #{ID} [options] <action> [options]"
      opts.separator ""
      opts.separator "Actions:"
      opts.separator "    show                             Displays component information"
      opts.separator "    check                            Performs health checks"
      opts.separator "    snap                             Saves contents of /proc/drbd and 'drbdadm dump-xml'"
      opts.separator ""
      opts.separator "General options:"
      opts.on('-D', '--drbdadm DRBDADM',                String,              "Path to drbdadm binary")                             { |drbdadm| @global_options[:drbdadm] = drbdadm }
      opts.on('-P', '--procdrbd PROCDRBD',              String,              "Path to /proc/drbd")                                 { |procdrbd| @global_options[:procdrbd] = procdrbd }
      opts.on('-X', '--xmldump XMLDUMP',                String,              "Path to output for drbdadm --dump-xml")              { |xmldump| @global_options[:xmldump] = xmldump}
      opts.on('-H', '--hostname HOSTNAME',              String,              "Hostname")                                           { |hostname| @global_options[:hostname] = hostname }
      opts.on('-d', '--debug',                                               "Enable debug mode")                                  { @global_options[:debug] = true}
      opts.on('-a', '--about',                                               "Display #{ID} information")                          { output_message ABOUT, 0 }
      opts.on('-V', '--version',                                             "Display #{ID} version")                              { output_message VERSION, 0 }
      opts.on_tail('--help',                                                 "Show this message")                                  { @global_options[:HELP] = true }

      actions = {
          :show => OptionParser.new do |aopts|
            aopts.banner = "Usage: #{ID} [options] show <component>"
            aopts.separator ""
            aopts.separator "      <component> is resources|res"
          end,
          :check => OptionParser.new do |aopts|
            aopts.banner = "Usage: #{ID} [options] check [check_options]"
            aopts.separator ""
            aopts.separator "Check Options"
            aopts.on('-M', '--monitor [nagios]',            [:nagios],            "Monitoring system")                                 { |monitor|        @action_options[:monitor] = monitor }
            aopts.on('-m', '--mode [active|passive]',       [:active, :passive],  "Monitoring mode")                                   { |mode|           @action_options[:mode] = mode }
            aopts.on('-H', '--nsca_hostname HOSTNAME',      String,               "NSCA hostname to send passive checks")              { |nsca_hostname|  @action_options[:nsca_hostname] = nsca_hostname }
            aopts.on('-c', '--config CONFIG',               String,               "Path to Senedsa (send_nsca) configuration" )        { |config|         @action_options[:senedsa_config] = config }
            aopts.on('-S', '--svc_descr SVC_DESR',          String,               "Nagios service description")                        { |svc_descr|      @action_options[:svc_descr] = svc_descr }
            aopts.on('-h', '--hostname HOSTNAME',           String,               "Service hostname")                                  { |hostname|       @action_options[:svc_hostname] = hostname }
          end,
          :snap => OptionParser.new do |aopts|
            aopts.banner = "Usage: #{ID} [options] snap [snap_options]"
            aopts.separator ""
            aopts.separator "Snap Options"
            aopts.on('-S','--suffix SUFFIX',                String,               "Suffix (defaults to PID)")                          { |suffix|            @action_options[:suffix] = suffix }
            aopts.on('-D', '--directory DIRECTORY',         String,               "Directory (defaults to /tmp)")                      { |directory|         @action_options[:directory] = directory }
          end
      }

      opts.order!(@arguments)
      output_message opts, 0 if (@arguments.size == 0 and @whoami != :check_drbd) or @global_options[:HELP]

      @action = @whoami == :check_drbd ? :check : @arguments.shift.to_sym
      raise OptionParser::InvalidArgument, "invalid action #@action" if actions[@action].nil?
      actions[@action].order!(@arguments)
    end

    def config_options?
      cfg_file = nil
      cfg_file = @action_options[:senedsa_config] unless @action_options[:senedsa_config].nil?
      cfg_file = DEFAULT_CONFIG_FILE if @action_options[:senedsa_config].nil? and File.readable? DEFAULT_CONFIG_FILE

      unless cfg_file.nil?
        @action_options.merge!(Senedsa::SendNsca.configure(cfg_file))
        @action_options[:senedsa_config] = cfg_file
      end
    end

    def arguments_valid?
      true
    end

    def options_valid?

      @global_options[:hostname] = Socket.gethostname if @global_options[:hostname].nil?

      case @action
        when :check
          raise OptionParser::MissingArgument, "NSCA hostname (-H) must be specified" if @action_options[:nsca_hostname].nil? and @action_options[:mode] == 'passive'
          raise OptionParser::MissingArgument, "service description (-S) must be specified" if @action_options[:svc_descr].nil? and @action_options[:mode] == 'passive'
      end
    end

    def process_options
      true
    end

    def process_arguments
      true
    end

    def process_command

      @drbdset = DrbdSet.new @global_options

      case @action
        when :show then run_show
        when :check then run_check
        when :snap then run_snap
      end

    end

    def run_show
      #raise ArgumentError, "missing component" if @arguments.size == 0
      component = 'res'

      case component
        when 'resource', 'res'
          @drbdset.each do |r,resource|
            puts resource.to_s
          end
        when 'version'
          puts @drbdset.version
      end
    end

    def run_check

      plugin_output = ""
      plugin_status = ""

      # check for configuration vs running resources

      #unconfigured_resources = @drbdset.select { |k,v| v.cstate == "Unconfigured" }

#      unless unconfigured_resources.empty?
#        plugin_output = "DRBD unconfigured resources found: #{unconfigured_resources.keys.join(' ')}"
#        plugin_status = :warning
#      end

      # check dstate, state and cstate for each resource
      # + cstate should be: Connected
      # + dstate should be: UpToDate/UpToDate

      @drbdset.each do |r,res|
        next if res.cstate == 'Unconfigured'

        po_cstate = ""
        po_dstate = ""

        po_cstate = "cs:#{res.cstate}" unless res.cstate == "Connected" and res.in_kernel? and res.in_configuration?
        po_dstate = "ds:#{res.dstate}" unless res.dstate == "UpToDate/UpToDate" and res.in_kernel? and res.in_configuration?

        unless po_cstate.gsub('cs:','').empty? and po_dstate.gsub('ds:','').empty?
          if ['SyncSource','SyncTarget','VerifyS','VerifyT','PausedSyncS','PausedSyncT','StandAlone'].include? res.cstate
            plugin_status = :warning
            plugin_output += res.percent.nil? ? " #{res.id}:#{po_cstate};#{po_dstate}" : " #{res.id}:#{po_cstate}[#{res.percent}%,#{res.finish}];#{po_dstate}"
          elsif not res.in_configuration?
            plugin_status = :warning
            plugin_output += " #{res.id}[unconfigured]>#{po_cstate}/;#{po_dstate}"
          else
            plugin_output += " #{res.id}>#{po_cstate};#{po_dstate}"
            plugin_status = :critical
          end
        end
      end

      plugin_output = " all DRBD resources Connected, UpToDate/UpToDate" if plugin_output.empty? and plugin_status.empty?
      plugin_status = :ok if plugin_status.empty?

      case @action_options[:monitor]
        when :nagios
          case @action_options[:mode]
            when :active
              puts "#{plugin_status.to_s.upcase}:#{plugin_output}"
              exit SendNsca::STATUS[plugin_status]
            when :passive
              sn = SendNsca.new @action_options
              begin
                sn.send plugin_status, plugin_output
              rescue SendNsca::SendNscaError => e
                output_message "send_nsca failed: #{e.message}", 1
              end
          end
      end
    end

    def run_snap
      @action_options[:suffix] = $$ if @action_options[:suffix].nil?
      procdrbd_file = "#{@action_options[:directory]}/procdrbd.#{@action_options[:suffix]}"
      xmldump_file = "#{@action_options[:directory]}/xmldump.#{@action_options[:suffix]}"
      File.open(procdrbd_file, 'w') {|f| f.write(@drbdset.resources_run_raw) }
      File.open(xmldump_file, 'w') {|f| f.write(@drbdset.resources_cfg_raw) }
    end

    def output_message(message, exitstatus=nil)
      m = (! exitstatus.nil? and exitstatus > 0) ? "%s: error: %s" % [ID, message] : message
      Syslog.open(ID.to_s, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.err "error: #{message}" } unless @global_options[:debug]
      $stderr.write "#{m}\n" if STDIN.tty?
      exit exitstatus unless exitstatus.nil?
    end

  end
end