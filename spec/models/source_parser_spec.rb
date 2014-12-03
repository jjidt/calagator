require 'spec_helper'

class SourceParser::FakeParser < SourceParser::Base
end

describe SourceParser, "when reading content", :type => :model do
  it "should read from a normal URL" do
    stub_source_parser_http_response!(:body => 42)
    expect(SourceParser.read_url("http://a.real/~url")).to eq 42
  end

  it "should read from a wacky URL" do
    uri = URI.parse('fake')
    # please retain space betwen "?" and ")" on following line; it avoids a SciTE issue
    allow(uri).to receive(:respond_to? ).and_return(false)
    allow(URI).to receive(:parse).and_return(uri)

    error_type = RUBY_PLATFORM.match(/mswin/) ? Errno::EINVAL : Errno::ENOENT
    expect { SourceParser.read_url("not://a.real/~url") }.to raise_error(error_type)
  end

  it "should unescape ATOM feeds" do
    content = "ATOM"
    allow(content).to receive(:content_type).and_return("application/atom+xml")

    expect(SourceParser::Base).to receive(:read_url).and_return(content)
    expect(CGI).to receive(:unescapeHTML).and_return("42")

    expect(SourceParser.content_for(:fake => :argument)).to eq "42"
  end
end

describe SourceParser, "when subclassing", :type => :model do
  it "should demand that to_hcals is implemented" do
    expect{ SourceParser::FakeParser.to_hcals }.to raise_error(NotImplementedError)
  end

  it "should demand that to_abstract_events is implemented" do
    expect{ SourceParser::FakeParser.to_abstract_events }.to raise_error NotImplementedError
  end
end

describe SourceParser, "when parsing events", :type => :model do
  it "should have expected parsers plus FakeParser" do
    expect(SourceParser.parsers).to eq [
      SourceParser::Plancast,
      SourceParser::Meetup,
      SourceParser::Facebook,
      SourceParser::Ical,
      SourceParser::Hcal,
      SourceParser::FakeParser,
    ]
  end

  it "should use first successful parser's results" do
    events = [double(SourceParser::AbstractEvent)]
    expect(SourceParser::Ical).to receive(:to_abstract_events).and_raise(NotImplementedError)
    expect(SourceParser::Hcal).to receive(:to_abstract_events).and_return(events)
    expect(SourceParser::FakeParser).not_to receive(:to_abstract_events)
    expect(SourceParser::Base).to receive(:content_for).and_return("fake content")

    expect(SourceParser.to_abstract_events(:fake => :argument)).to eq events
  end
end

describe SourceParser, "checking duplicates when importing", :type => :model do
  describe "with two identical events" do
    before :each do
      @venue_size_before_import = Venue.count
      @cal_source = Source.new(:title => "Calendar event feed", :url => "http://mysample.hcal/")
      @cal_content = (%{
      <div class="vevent">
        <abbr class="dtstart" title="20080714"></abbr>
        <abbr class="summary" title="Bastille Day"></abbr>
        <abbr class="location" title="Arc de Triomphe"></abbr>
      </div>
      <div class="vevent">
        <abbr class="dtstart" title="20080714"></abbr>
        <abbr class="summary" title="Bastille Day"></abbr>
        <abbr class="location" title="Arc de Triomphe"></abbr>
      </div>})
      allow(SourceParser::Base).to receive(:read_url).and_return(@cal_content)
      @abstract_events = @cal_source.to_events
      @created_events = @cal_source.create_events!(:skip_old => false)
    end

    it "should only parse one event" do
      expect(@abstract_events.size).to eq 1
    end

    it "should create only one event" do
      expect(@created_events.size).to eq 1
    end

    it "should create only one venue" do
      expect(Venue.count).to eq @venue_size_before_import + 1
    end
  end

  describe "with an event" do
    it "should retrieve an existing event if it's an exact duplicate" do
      hcal_source = Source.new(:title => "Calendar event feed", :url => "http://mysample.hcal/")
      hcal_content = read_sample('hcal_event_duplicates_fixture.xml')
      allow(SourceParser::Base).to receive(:read_url).and_return(hcal_content)

      event = hcal_source.to_events.first
      event.save!

      event2 = hcal_source.to_events.first
      expect(event2).not_to be_a_new_record
    end

    it "an event with a orphaned exact duplicate should should remove duplicate marking" do
      orphan = Event.create!(:title => "orphan", :start_time => Time.parse("July 14 2008"), :duplicate_of_id => 7142008 )
      cal_content = <<-HERE
        <div class="vevent">
        <abbr class="summary" title="orphan"></abbr>
        <abbr class="dtstart" title="20080714"></abbr>
        </div>
      HERE
      allow(SourceParser::Base).to receive(:read_url).and_return(cal_content)

      cal_source = Source.new(:title => "Calendar event feed", :url => "http://mysample.hcal/")
      imported_event = cal_source.create_events!(:skip_old => false).first
      expect(imported_event).not_to be_marked_as_duplicate
    end
  end

  describe "should create two events when importing two non-identical events" do
    # This behavior is tested under
    #  describe SourceParser::Hcal, "with hCalendar events" do
    #  'it "should parse a page with multiple events" '
  end

  describe "two identical events with different venues" do
    before(:each) do
      cal_content = <<-HERE
        <div class="vevent">
          <abbr class="dtstart" title="20080714"></abbr>
          <abbr class="summary" title="Bastille Day"></abbr>
          <abbr class="location" title="Arc de Triomphe"></abbr>
        </div>
        <div class="vevent">
          <abbr class="dtstart" title="20080714"></abbr>
          <abbr class="summary" title="Bastille Day"></abbr>
          <abbr class="location" title="Bastille"></abbr>
        </div>
      HERE
      allow(SourceParser::Base).to receive(:read_url).and_return(cal_content)

      cal_source = Source.new(:title => "Calendar event feed", :url => "http://mysample.hcal/")
      @parsed_events  = cal_source.to_events
      @created_events = cal_source.create_events!(:skip_old => false)
    end

    it "should parse two events" do
      expect(@parsed_events.size).to eq 2
    end

    it "should create two events" do
      expect(@created_events.size).to eq 2
    end

     it "should have different venues for the parsed events" do
      expect(@parsed_events[0].venue).not_to eq @parsed_events[1].venue
    end

     it "should have different venues for the created events" do
      expect(@created_events[0].venue).not_to eq @created_events[1].venue
    end
  end

  it "should use an existing venue when importing an event whose venue matches a squashed duplicate"  do
    dummy_source = Source.create!(:title => "Dummy", :url => "http://IcalEventWithSquashedVenue.com/")
    master_venue = Venue.create!(:title => "Master")
    squashed_venue = Venue.create!(
      :title => "Squashed Duplicate Venue",
      :duplicate_of_id => master_venue.id)

    cal_content = <<-HERE
      <div class="vevent">
        <abbr class="dtstart" title="20090117"></abbr>
        <abbr class="summary" title="Event with cloned venue"></abbr>
        <abbr class="location" title="Squashed Duplicate Venue"></abbr>
      </div>
    HERE

    allow(SourceParser::Base).to receive(:read_url).and_return(cal_content)

    source = Source.new(
      :title => "Event with squashed venue",
      :url   => "http://IcalEventWithSquashedVenue.com/")

    event = source.to_events(:skip_old => false).first
    expect(event.venue.title).to eq "Master"
  end

  it "should use an existing venue when importing an event with a matching machine tag that describes a venue" do
    venue = Venue.create!(:title => "Custom Urban Airship", :tag_list => "plancast:place=1520153")

    content = read_sample('plancast.json')
    allow(SourceParser::Base).to receive(:read_url).and_return("this content doesn't matter")
    expect(HTTParty).to receive(:get).and_return(MultiJson.decode(content))

    source = Source.new(
      :title => "Event with duplicate machine-tagged venue",
      :url   => "http://plancast.com/p/3cos/indiewebcamp")

    event = source.to_events(:skip_old => false).first

    expect(event.venue).to eq venue
  end

  describe "choosing parsers by matching URLs" do
    { "SourceParser::Plancast" => "http://plancast.com/p/3cos/indiewebcamp",
      "SourceParser::Meetup"   => "http://www.meetup.com/pdxweb/events/23287271/" }.each do |parser_name, url|

      it "should only invoke the #{parser_name} parser when given #{url}" do
        parser = parser_name.constantize
        expect(parser).to receive(:to_abstract_events).and_return([Event.new])
        SourceParser.parsers.reject{|p| p == parser }.each do |other_parser|
          expect(other_parser).not_to receive :to_abstract_events
        end

        allow(SourceParser::Base).to receive(:read_url).and_return("this content doesn't matter")
        Source.new(:title => parser_name, :url => url).to_events
      end
    end
  end
end

describe SourceParser, "labels", :type => :model do
  it "should have labels" do
    expect(SourceParser.labels).not_to be_blank
  end

  it "should have labels for each parser" do
    expect(SourceParser.labels.size).to eq SourceParser.parsers.size
  end

  it "should use the label of the parser, as a string" do
    label = SourceParser.parsers.first.label.to_s
    expect(SourceParser.labels).to include label
  end

  it "should have sorted labels" do
    labels = SourceParser.labels
    sorted = labels.sort_by(&:downcase)

    expect(labels).to eq sorted
  end
end
