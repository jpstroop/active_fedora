require 'spec_helper'
require 'config_helper'

describe ActiveFedora::FileConfigurator do
  
  before :each do
    @configurator = ActiveFedora.configurator
  end
  
  after :all do
    unstub_rails
    # Restore to default fedora configs
    restore_spec_configuration
  end

  describe "initialization methods" do
    
    describe "get_config_path(:fedora)" do
      it "should use the config_options[:config_path] if it exists" do
        @configurator.expects(:config_options).at_least_once.returns({:fedora_config_path => "/path/to/fedora.yml"})
        File.expects(:file?).with("/path/to/fedora.yml").returns(true)
        @configurator.get_config_path(:fedora).should eql("/path/to/fedora.yml")
      end

      it "should look in Rails.root/config/fedora.yml if it exists and no fedora_config_path passed in" do
        @configurator.expects(:config_options).at_least_once.returns({})
        stub_rails(:root => "/rails/root")
        File.expects(:file?).with("/rails/root/config/fedora.yml").returns(true)
        @configurator.get_config_path(:fedora).should eql("/rails/root/config/fedora.yml")
        unstub_rails
      end

      it "should look in ./config/fedora.yml if neither rails.root nor :fedora_config_path are set" do
        @configurator.expects(:config_options).at_least_once.returns({})
        Dir.expects(:getwd).at_least_once.returns("/current/working/directory")
        File.expects(:file?).with("/current/working/directory/config/fedora.yml").returns(true)
        @configurator.get_config_path(:fedora).should eql("/current/working/directory/config/fedora.yml")
      end

      it "should return default fedora.yml that ships with active-fedora if none of the above" do
        @configurator.expects(:config_options).at_least_once.returns({})
        Dir.expects(:getwd).at_least_once.returns("/current/working/directory")
        File.expects(:file?).with("/current/working/directory/config/fedora.yml").returns(false)
        File.expects(:file?).with(File.expand_path(File.join(File.dirname("__FILE__"),'config','fedora.yml'))).returns(true)
        logger.expects(:warn).with("Using the default fedora.yml that comes with active-fedora.  If you want to override this, pass the path to fedora.yml to ActiveFedora - ie. ActiveFedora.init(:fedora_config_path => '/path/to/fedora.yml') - or set Rails.root and put fedora.yml into \#{Rails.root}/config.")
        @configurator.get_config_path(:fedora).should eql(File.expand_path(File.join(File.dirname("__FILE__"),'config','fedora.yml')))
      end
    end

    describe "get_config_path(:solr)" do
      it "should return the solr_config_path if set in config_options hash" do
        @configurator.expects(:config_options).at_least_once.returns({:solr_config_path => "/path/to/solr.yml"})
        File.expects(:file?).with("/path/to/solr.yml").returns(true)
        @configurator.get_config_path(:solr).should eql("/path/to/solr.yml")
      end
      
      it "should return the solr.yml file in the same directory as the fedora.yml if it exists" do
        @configurator.expects(:path).returns("/path/to/fedora/config/fedora.yml")
        File.expects(:file?).with("/path/to/fedora/config/solr.yml").returns(true)
        @configurator.get_config_path(:solr).should eql("/path/to/fedora/config/solr.yml")
      end
      
      context "no solr.yml in same directory as fedora.yml and fedora.yml does not contain solr url" do

        before :each do
          @configurator.expects(:config_options).at_least_once.returns({})
          @configurator.expects(:path).returns("/path/to/fedora/config/fedora.yml")
          File.expects(:file?).with("/path/to/fedora/config/solr.yml").returns(false)
        end
        after :each do
          unstub_rails
        end

        it "should not raise an error if there is not a solr.yml in the same directory as the fedora.yml and the fedora.yml has a solr url defined and look in rails.root" do
          stub_rails(:root=>"/rails/root")
          File.expects(:file?).with("/rails/root/config/solr.yml").returns(true)
          @configurator.get_config_path(:solr).should eql("/rails/root/config/solr.yml")
        end

        it "should look in ./config/solr.yml if no rails root" do
          Dir.expects(:getwd).at_least_once.returns("/current/working/directory")
          File.expects(:file?).with("/current/working/directory/config/solr.yml").returns(true)
          @configurator.get_config_path(:solr).should eql("/current/working/directory/config/solr.yml")
        end

        it "should return the default solr.yml file that ships with active-fedora if no other option is set" do
          Dir.expects(:getwd).at_least_once.returns("/current/working/directory")
          File.expects(:file?).with("/current/working/directory/config/solr.yml").returns(false)
          File.expects(:file?).with(File.expand_path(File.join(File.dirname("__FILE__"),'config','solr.yml'))).returns(true)
          logger.expects(:warn).with("Using the default solr.yml that comes with active-fedora.  If you want to override this, pass the path to solr.yml to ActiveFedora - ie. ActiveFedora.init(:solr_config_path => '/path/to/solr.yml') - or set Rails.root and put solr.yml into \#{Rails.root}/config.")
          @configurator.get_config_path(:solr).should eql(File.expand_path(File.join(File.dirname("__FILE__"),'config','solr.yml')))
        end
      end

    end

    describe "#determine url" do
      it "should support config['environment']['url'] if config_type is fedora" do
        config = {:test=> {:url=>"http://fedoraAdmin:fedorAdmin@localhost:8983/fedora"}}
        @configurator.determine_url("fedora",config).should eql("http://localhost:8983/fedora")
      end

      it "should call #get_solr_url to determine the solr url if config_type is solr" do
        config = {:test=>{:default => "http://default.solr:8983"}}
        @configurator.expects(:get_solr_url).with(config[:test]).returns("http://default.solr:8983")
        @configurator.determine_url("solr",config).should eql("http://default.solr:8983")
      end
    end

    describe "load_config" do
      it "should load the file specified in solr_config_path" do
        @configurator.expects(:solr_config_path).returns("/path/to/solr.yml")
        File.expects(:open).with("/path/to/solr.yml").returns("development:\n  default:\n    url: http://devsolr:8983\ntest:\n  default:\n    url: http://mysolr:8080")
        @configurator.load_config(:solr).should eql({:url=>"http://mysolr:8080",:development=>{"default"=>{"url"=>"http://devsolr:8983"}}, :test=>{:default=>{"url"=>"http://mysolr:8080"}}})
        @configurator.solr_config.should eql({:url=>"http://mysolr:8080",:development=>{"default"=>{"url"=>"http://devsolr:8983"}}, :test=>{:default=>{"url"=>"http://mysolr:8080"}}})
      end
    end

    describe "load_configs" do
      describe "when config is not loaded" do
        before do
          @configurator.instance_variable_set :@config_loaded, nil
        end
        it "should load the fedora and solr configs" do
          #ActiveFedora.expects(:load_config).with(:fedora)
          @configurator.expects(:load_config).with(:solr)
          @configurator.config_loaded?.should be_false
          @configurator.load_configs
          @configurator.config_loaded?.should be_true
        end
      end
      describe "when config is loaded" do
        before do
          @configurator.instance_variable_set :@config_loaded, true
        end
        it "should load the fedora and solr configs" do
          @configurator.expects(:load_config).never
          @configurator.config_loaded?.should be_true
          @configurator.load_configs
          @configurator.config_loaded?.should be_true
        end
      end
    end

    describe "check_fedora_path_for_solr" do
      it "should find the solr.yml file and return it if it exists" do
        @configurator.expects(:path).returns("/path/to/fedora/fedora.yml")
        File.expects(:file?).with("/path/to/fedora/solr.yml").returns(true)
        @configurator.check_fedora_path_for_solr.should == "/path/to/fedora/solr.yml"
      end
      it "should return nil if the solr.yml file is not there" do
        @configurator.expects(:path).returns("/path/to/fedora/fedora.yml")
        File.expects(:file?).with("/path/to/fedora/solr.yml").returns(false)
        @configurator.check_fedora_path_for_solr.should be_nil
      end
    end
  end
  
  describe "setting the environment and loading configuration" do
    
    before(:all) do
      @fake_rails_root = File.expand_path(File.dirname(__FILE__) + '/../fixtures/rails_root')
    end

    
    after(:all) do
      config_file = File.join(File.dirname(__FILE__), "..", "..", "config", "fedora.yml")
      environment = "test"
      ActiveFedora.init(:environment=>environment, :fedora_config_path=>config_file)
    end
  
    it "can tell its config paths" do
      @configurator.init
      @configurator.should respond_to(:solr_config_path)
    end
    it "loads a config from the current working directory as a second choice" do
      Dir.stubs(:getwd).returns(@fake_rails_root)
      @configurator.init
      @configurator.get_config_path(:fedora).should eql("#{@fake_rails_root}/config/fedora.yml")
      @configurator.solr_config_path.should eql("#{@fake_rails_root}/config/solr.yml")
    end
    it "loads the config that ships with this gem as a last choice" do
      Dir.stubs(:getwd).returns("/fake/path")
      logger.expects(:warn).with("Using the default fedora.yml that comes with active-fedora.  If you want to override this, pass the path to fedora.yml to ActiveFedora - ie. ActiveFedora.init(:fedora_config_path => '/path/to/fedora.yml') - or set Rails.root and put fedora.yml into \#{Rails.root}/config.").times(3)
      @configurator.init
      expected_config = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config"))
      @configurator.get_config_path(:fedora).should eql(expected_config+'/fedora.yml')
      @configurator.solr_config_path.should eql(expected_config+'/solr.yml')
    end
    it "raises an error if you pass in a string" do
      lambda{ @configurator.init("#{@fake_rails_root}/config/fake_fedora.yml") }.should raise_exception(ArgumentError)
    end
    it "raises an error if you pass in a non-existant config file" do
      lambda{ @configurator.init(:fedora_config_path=>"really_fake_fedora.yml") }.should raise_exception(ActiveFedora::ConfigurationError)
    end
    
    describe "within Rails" do
      before(:all) do        
        stub_rails(:root=>File.dirname(__FILE__) + '/../fixtures/rails_root')
      end

      after(:all) do
        unstub_rails
      end
      
      it "loads a config from Rails.root as a first choice" do
        @configurator.init
        @configurator.get_config_path(:fedora).should eql("#{Rails.root}/config/fedora.yml")
        @configurator.solr_config_path.should eql("#{Rails.root}/config/solr.yml")
      end
      
      it "can tell what environment it is set to run in" do
        stub_rails(:env=>"development")
        @configurator.init
        ActiveFedora.environment.should eql("development")
      end
      
    end
  end
  
  ##########################
  
  describe ".build_predicate_config_path" do
    it "should return the path to the default config/predicate_mappings.yml if no valid path is given" do
      @configurator.send(:build_predicate_config_path, nil).should == default_predicate_mapping_file
    end

    it "should return the path to the default config/predicate_mappings.yml if specified config file not found" do
      File.expects(:exist?).with("/path/to/predicate_mappings.yml").returns(false)
      File.expects(:exist?).with(default_predicate_mapping_file).returns(true)
      @configurator.send(:build_predicate_config_path,"/path/to").should == default_predicate_mapping_file
    end

    it "should return the path to the specified config_path if it exists" do
      File.expects(:exist?).with("/path/to/predicate_mappings.yml").returns(true)
      @configurator.expects(:valid_predicate_mapping?).returns(true)
      @configurator.send(:build_predicate_config_path,"/path/to").should == "/path/to/predicate_mappings.yml"
    end    
  end

  describe ".predicate_config" do
    before do
      @configurator.instance_variable_set :@config_loaded, nil
    end
    it "should return the default mapping if it has not been initialized" do
      @configurator.predicate_config().should == YAML.load(File.read(default_predicate_mapping_file))
    end
  end

  describe ".valid_predicate_mapping" do
    it "should return true if the predicate mapping has the appropriate keys and value types" do
      @configurator.send(:valid_predicate_mapping?,default_predicate_mapping_file).should be_true
    end
    it "should return false if the mapping is missing the :default_namespace" do
      mock_yaml({:default_namespace0=>"my_namespace",:predicate_mapping=>{:key0=>"value0", :key1=>"value1"}},"/path/to/predicate_mappings.yml")
      @configurator.send(:valid_predicate_mapping?,"/path/to/predicate_mappings.yml").should be_false
    end
    it "should return false if the :default_namespace is not a string" do
      mock_yaml({:default_namespace=>{:foo=>"bar"}, :predicate_mapping=>{:key0=>"value0", :key1=>"value1"}},"/path/to/predicate_mappings.yml")
      @configurator.send(:valid_predicate_mapping?,"/path/to/predicate_mappings.yml").should be_false
    end
    it "should return false if the :predicate_mappings key is missing" do
      mock_yaml({:default_namespace=>"a string"},"/path/to/predicate_mappings.yml")
      @configurator.send(:valid_predicate_mapping?,"/path/to/predicate_mappings.yml").should be_false
    end
    it "should return false if the :predicate_mappings key is not a hash" do
      mock_yaml({:default_namespace=>"a string",:predicate_mapping=>"another string"},"/path/to/predicate_mappings.yml")
      @configurator.send(:valid_predicate_mapping?,"/path/to/predicate_mappings.yml").should be_false
    end

  end

end