require 'xmlsimple'
require 'ostruct'
require 'awesome_print'

module Dribbled

  class DrbdSet < Hash

    attr_reader :resources_cfg_raw, :resources_run_raw

    PROCDRBD_VERSION_RE = /^version:\s+(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\s+\(api:(?<api>\d+)\/proto:(?<proto>[0-9-]+)/
    PROCDRBD_RESOURCE_RE = /^\s*(?<id>\d+):\s+cs:(?<cstate>[\w\/]+)\s+(st|ro):(?<state>[\w\/]+)\s+ds:(?<dstate>[\w\/]+)\s+/
    PROCDRBD_URESOURCE_RE = /^\s*(?<id>\d+):\s+cs:(?<cstate>[\w\/]+)/
    PROCDRBD_ACTIVITY_RE = /^\s+\[[.>=]+\]\s+(?<activity>[a-z']+):\s+(?<percent>[0-9.]+)%\s+\(\d+\/\d+\)M(finish:\s+(?<finish>[0-9:]+)\s+)*/
    PROCDRBD_ACTIVITY_STATUS_RE = /^\s+finish:\s+(?<finish>[0-9:]+)\s+/

    def initialize(options)
      @log = options[:log].nil? ? nil : options[:log]
      @hostname = options[:hostname]

      resources_run_src = options[:procdrbd]
      @resources_run_raw = nil
      @resources_run = _read_procdrbd(resources_run_src) # sets @resources_run_raw as side-effect; it shouldn't
      @resources_run.each do |r,res|
        self[res.id] = res unless res.nil?
      end

      resources_cfg_src = options[:xmldump].nil? ? IO.popen("#{options[:drbdadm]} dump-xml 2>/dev/null") : options[:xmldump]
      @resources_cfg_raw = nil
      @resources_cfg = _read_xmldump(resources_cfg_src)  # sets @resources_cfg_raw as side-effect; it shouldn't

      @resources_cfg.each do |name,res|
        _process_xml_resource(name,res)
      end

    end

    def version
      "#@version_major.#@version_minor.#@version_path"
    end

    protected

      def _read_procdrbd(resources_run_src)
        @log.debug "Running configuration source: #{resources_run_src}" unless @log.nil?
        resources_run = {}
        @resources_run_raw = File.open(resources_run_src,"r") { |f| f.read }
        r = nil
        @resources_run_raw.each_line do |line|
          if /^\s*(\d+):/.match(line)
            r = $1.to_i
            resources_run[r] = DrbdResource.new r, @hostname
            resources_run[r].in_kernel = true
            if PROCDRBD_RESOURCE_RE.match(line)
              m = PROCDRBD_RESOURCE_RE.match(line)
              resources_run[r].cstate = m[:cstate]
              resources_run[r].state  = m[:state]
              resources_run[r].dstate = m[:dstate]
            elsif PROCDRBD_URESOURCE_RE.match(line)
              resources_run[r].cstate = PROCDRBD_URESOURCE_RE.match(line)[:cstate]
            end
            @log.debug "  #{resources_run[r].inspect}" unless @log.nil?
          elsif PROCDRBD_ACTIVITY_RE.match(line)
            m = PROCDRBD_ACTIVITY_RE.match(line)
            resources_run[r].activity = m[:activity].gsub(/'/,"").to_sym
            resources_run[r].percent = m[:percent].to_f
            resources_run[r].finish = m[:finish]
          elsif PROCDRBD_ACTIVITY_STATUS_RE.match(line)
            m = PROCDRBD_ACTIVITY_STATUS_RE.match(line)
            resources_run[r].finish = m[:finish]
          elsif PROCDRBD_VERSION_RE.match(line)
            @version_major = $1
            @version_minor = $2
            @version_path = $3
          end
        end
        resources_run
      end

      def _read_xmldump(resources_cfg_src)
        @log.debug "Stable configuration source: #{resources_cfg_src}" unless @log.nil?
        @resources_cfg_raw = resources_cfg_src.is_a?(String) ? File.open(resources_cfg_src,"r") { |f| f.read } : resources_cfg_src.read
        XmlSimple.xml_in(@resources_cfg_raw, { 'KeyAttr' => 'name' })['resource']
      end

      def _process_xml_resource(name,res)
        res['host'].each_key do |hostname|
          @log.debug "  resource xml processing: host #{hostname}"
          if res['host'][hostname]['device'][0]['minor'].nil?
            r = res['host'][hostname]['device'][0].split('drbd')[1].to_i
            @log.debug "    #{version}: #{res['host'][hostname]['device'][0]}; r = #{r}"
            disk = res['host'][hostname]['disk'][0]
            device =  res['host'][hostname]['device'][0]
          else
            r = res['host'][hostname]['device'][0]['minor'].to_i
            @log.debug "    #{version}: #{res['host'][hostname]['device'][0]}; r = #{r}"
            disk = res['host'][hostname]['disk'][0]
            device = res['host'][hostname]['device'][0]['content']
          end
          if self[r].nil?
            self[r] = DrbdResource.new r, @hostname
            self[r].cstate = "StandAlone"
            self[r].dstate = "DUnknown"
            self[r].state = "Unknown"
          end
          self[r].name = name
          self[r].in_configuration = true
          @log.debug "    resource: #{r}, state: #{self[r].state}"
          if self[r].state == 'Primary/Secondary'
            if hostname == @hostname
              @log.debug "    resource: #{r}, primary"
              self[r].primary[:disk] = disk
              self[r].primary[:device] = device
              self[r].primary[:hostname] = hostname
            else
              @log.debug "    resource: #{r}, secondary"
              self[r].secondary[:disk] = disk
              self[r].secondary[:device] = device
              self[r].secondary[:hostname] = hostname
            end
          elsif self[r].state == 'Secondary/Primary' or self[r].state == 'Unknown'
            if hostname == @hostname
              @log.debug "    resource: #{r}, secondary"
              self[r].secondary[:disk] = disk
              self[r].secondary[:device] = device
              self[r].secondary[:hostname] = hostname
            else
              @log.debug "    resource: #{r}, primary"
              self[r].primary[:disk] = disk
              self[r].primary[:device] = device
              self[r].primary[:hostname] = hostname
            end
          end
        end
      end
  end

  class DrbdResource

    attr_reader :id
    attr_accessor :name, :cstate, :dstate, :state, :config, :primary, :secondary, :activity, :percent, :finish, :in_kernel, :in_configuration

    def initialize(res,hostname)
      @id = res
      @name = nil
      @config = nil
      @dstate = nil
      @cstate = nil
      @state = nil
      @activity = nil
      @percent = nil
      @finish = nil
      @primary = { :hostname => nil, :disk => nil, :device => nil }
      @secondary = { :hostname => nil, :disk => nil, :device => nil }
      @in_kernel = false
      @in_configuration = false
    end

    def in_kernel?
      @in_kernel
    end

    def in_configuration?
      @in_configuration
    end

    def to_s
      ph = @primary[:hostname].gsub(/\.[a-z0-9-]+\.[a-z0-9-]+$/,"") unless @primary[:hostname].nil?
      sh = @secondary[:hostname].gsub(/\.[a-z0-9-]+\.[a-z0-9-]+$/,"") unless @secondary[:hostname].nil?

      if @state == 'Primary/Secondary'
        h1 = ph; dev1 = @primary[:device]
        h2 = sh; dev2 = @secondary[:device]
      else
        h1 = sh; dev1 = @secondary[:device]
        h2 = ph; dev2 = @primary[:device]
      end

      percent_finish = @activity.nil? ? nil : "[%3d%% %8s]" % [@percent,@finish]

      "%2d %6s %-13s %15s %-22s %-20s %10s %-11s %10s %-11s" % [@id,@name,@cstate,percent_finish,@dstate,@state,h1,dev1,h2,dev2]
    end

    def inspect
      "#{self.class}: #@id[#@name]: #@cstate,#@dstate,#@state"
    end

    def check

    end
  end
end
