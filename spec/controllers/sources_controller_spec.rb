require 'spec_helper'

describe SourcesController do
  describe "using import logic" do
    before(:each) do
      @venue = mock_model(Venue,
        :source => nil,
        :source= => true,
        :save! => true,
        :duplicate_of_id =>nil)

      @event = mock_model(Event,
        :title => "Super Event",
        :source= => true,
        :save! => true,
        :venue => @venue,
        :start_time => Time.now+1.week,
        :end_time => nil,
        :duplicate_of_id => nil)

      @source = Source.new(:url => "http://my.url/")
      @source.stub(:save!).and_return(true)
      @source.stub(:to_events).and_return([@event])

      Source.stub(:new).and_return(@source)
      Source.stub(:find_or_create_by_url).and_return(@source)
    end

    it "should provide a way to create new sources" do
      get :new
      expect(assigns(:source)).to be_a_kind_of Source
      expect(assigns(:source)).to be_a_new_record
    end

    describe "with render views" do
      render_views

      it "should save the source object when creating events" do
        @source.should_receive(:save!)
        post :import, :source => {:url => @source.url}
        expect(flash[:success]).to match /Imported/i
      end

      it "should limit the number of created events to list in the flash" do
        excess = 5
        events = (1..(5+excess))\
          .inject([]){|result,i| result << @event; result}
        @source.should_receive(:to_events).and_return(events)
        post :import, :source => {:url => @source.url}
        expect(flash[:success]).to match /And #{excess} other events/si
      end
    end

    it "should assign newly-created events to the source" do
      @event.should_receive(:save!)
      post :import, :source => {:url => @source.url}
    end

    it "should assign newly created venues to the source" do
      @venue.should_receive(:save!)
      post :import, :source => {:url => @source.url}
    end


    describe "is given problematic sources" do
      before do
        @source = stub_model(Source)
        Source.should_receive(:find_or_create_from).and_return(@source)
      end

      def assert_import_raises(exception)
        @source.should_receive(:create_events!).and_raise(exception)
        post :import, :source => {:url => "http://invalid.host"}
      end

      it "should fail when host responds with an error" do
        assert_import_raises(OpenURI::HTTPError.new("omfg", "bbq"))
        expect(flash[:failure]).to match /Couldn't download events/
      end

      it "should fail when host is not responding" do
        assert_import_raises(Errno::EHOSTUNREACH.new("omfg"))
        expect(flash[:failure]).to match /Couldn't connect to remote site/
      end

      it "should fail when host is not found" do
        assert_import_raises(SocketError.new("omfg"))
        expect(flash[:failure]).to match /Couldn't find IP address for remote site/
      end

      it "should fail when host requires authentication" do
        assert_import_raises(SourceParser::HttpAuthenticationRequiredError.new("omfg"))
        expect(flash[:failure]).to match /requires authentication/
      end
    end
  end


  describe "handling GET /sources" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub(:listing).and_return([@source])
    end

    def do_get
      get :index
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should render index template" do
      do_get
      expect(response).to render_template :index
    end

    it "should find sources" do
      Source.should_receive(:listing).and_return([@source])
      do_get
    end

    it "should assign the found sources for the view" do
      do_get
      expect(assigns[:sources]).to eq [@source]
    end
  end

  describe "handling GET /sources.xml" do

    before(:each) do
      @sources = double("Array of Sources", :to_xml => "XML")
      Source.stub(:find).and_return(@sources)
    end

    def do_get
      @request.env["HTTP_ACCEPT"] = "application/xml"
      get :index
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should find all sources" do
      Source.should_receive(:listing).and_return(@sources)
      do_get
    end

    it "should render the found sources as xml" do
      do_get
      expect(response.content_type).to eq 'application/xml'
    end
  end

  describe "show" do
    it "should redirect when asked for unknown source" do
      Source.should_receive(:find).and_raise(ActiveRecord::RecordNotFound.new)
      get :show, :id => "1"

      expect(response).to be_redirect
    end
  end

  describe "handling GET /sources/1" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub(:find).and_return(@source)
    end

    def do_get
      get :show, :id => "1"
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should render show template" do
      do_get
      expect(response).to render_template :show
    end

    it "should find the source requested" do
      Source.should_receive(:find).with("1", :include => [:events, :venues]).and_return(@source)
      do_get
    end

    it "should assign the found source for the view" do
      do_get
      expect(assigns[:source]).to eq @source
    end
  end

  describe "handling GET /sources/1.xml" do

    before(:each) do
      @source = mock_model(Source, :to_xml => "XML")
      Source.stub(:find).and_return(@source)
    end

    def do_get
      @request.env["HTTP_ACCEPT"] = "application/xml"
      get :show, :id => "1"
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should find the source requested" do
      Source.should_receive(:find).with("1", :include => [:events, :venues]).and_return(@source)
      do_get
    end

    it "should render the found source as xml" do
      @source.should_receive(:to_xml).and_return("XML")
      do_get
      expect(response.body).to eq "XML"
    end
  end

  describe "handling GET /sources/new" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub(:new).and_return(@source)
    end

    def do_get
      get :new
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should render new template" do
      do_get
      expect(response).to render_template :new
    end

    it "should create an new source" do
      Source.should_receive(:new).and_return(@source)
      do_get
    end

    it "should not save the new source" do
      @source.should_not_receive(:save)
      do_get
    end

    it "should assign the new source for the view" do
      do_get
      expect(assigns[:source]).to eq @source
    end
  end

  describe "handling GET /sources/1/edit" do

    before(:each) do
      @source = mock_model(Source)
      Source.stub(:find).and_return(@source)
    end

    def do_get
      get :edit, :id => "1"
    end

    it "should be successful" do
      do_get
      expect(response).to be_success
    end

    it "should render edit template" do
      do_get
      expect(response).to render_template :edit
    end

    it "should find the source requested" do
      Source.should_receive(:find).and_return(@source)
      do_get
    end

    it "should assign the found Source for the view" do
      do_get
      expect(assigns[:source]).to eq @source
    end
  end

  describe "handling POST /sources" do

    before(:each) do
      @source = mock_model(Source, :to_param => "1")
      Source.stub(:new).and_return(@source)
    end

    describe "with successful save" do

      def do_post
        @source.should_receive(:update_attributes).and_return(true)
        post :create, :source => {}
      end

      it "should create a new source" do
        Source.should_receive(:new).and_return(@source)
        do_post
      end

      it "should redirect to the new source" do
        do_post
        expect(response).to redirect_to(source_url("1"))
      end

    end

    describe "with failed save" do

      def do_post
        @source.should_receive(:update_attributes).and_return(false)
        @source.stub(new_record?: true)
        post :create, :source => {}
      end

      it "should re-render 'new'" do
        do_post
        expect(response).to render_template :new
      end

    end
  end

  describe "handling PUT /sources/1" do

    before(:each) do
      @source = mock_model(Source, :to_param => "1")
      Source.stub(:find).and_return(@source)
    end

    describe "with successful update" do

      def do_put
        @source.should_receive(:update_attributes).and_return(true)
        put :update, :id => "1"
      end

      it "should find the source requested" do
        Source.should_receive(:find).with("1").and_return(@source)
        do_put
      end

      it "should update the found source" do
        do_put
        expect(assigns(:source)).to eq @source
      end

      it "should assign the found source for the view" do
        do_put
        expect(assigns(:source)).to eq @source
      end

      it "should redirect to the source" do
        do_put
        expect(response).to redirect_to(source_url("1"))
      end

    end

    describe "with failed update" do

      def do_put
        @source.should_receive(:update_attributes).and_return(false)
        put :update, :id => "1"
      end

      it "should re-render 'edit'" do
        do_put
        expect(response).to render_template :edit
      end

    end
  end

  describe "handling DELETE /sources/1" do

    before(:each) do
      @source = mock_model(Source, :destroy => true)
      Source.stub(:find).and_return(@source)
    end

    def do_delete
      delete :destroy, :id => "1"
    end

    it "should find the source requested" do
      Source.should_receive(:find).with("1").and_return(@source)
      do_delete
    end

    it "should call destroy on the found source" do
      @source.should_receive(:destroy)
      do_delete
    end

    it "should redirect to the sources list" do
      do_delete
      expect(response).to redirect_to(sources_url)
    end
  end
end
