#coding: UTF-8
require 'rails_helper'

feature 'Event Creation' do
  scenario 'User adds an event at an existing venue' do
    create :venue, title: 'Empire State Building'

    visit '/'
    click_on 'Add an event'

    fill_in 'Event Name', with: 'Ruby Newbies'
    find_field('Venue').native.send_keys 'Empire State'
    click_on 'Empire State Building'

    fill_in 'start_date', with: '2014-08-05'
    fill_in 'start_time', with: '06:00 PM'
    fill_in 'end_time', with: '11:00 PM'
    fill_in 'end_date', with: '2014-08-06'
    fill_in 'Website', with: 'www.rubynewbies.com'
    fill_in 'Description', with: 'An event for beginners'
    fill_in 'Venue details', with: 'On the third floor'
    fill_in 'Tags', with: 'beginners,ruby'

    click_on 'Create Event'

    page.should have_content 'Event was successfully saved'
    page.should have_content 'Ruby Newbies'
    page.should have_content 'Empire State Building'
    page.should have_content 'Tuesday, August 5, 2014 at 6pm through Wednesday, August 6, 2014 at 11pm'
    page.should have_content 'Website http://www.rubynewbies.com'
    page.should have_content 'Description An event for beginners'
    page.should have_content 'On the third floor'
    page.should have_content 'Tags beginners, ruby'
  end

  scenario 'User adds an event at a new venue' do
    visit '/'
    click_on 'Add an event'

    fill_in 'Event Name', with: 'Ruby Zoo'
    fill_in 'Venue', with: 'Portland Zoo'
    fill_in 'start_date', with: '2014-05-15'
    fill_in 'start_time', with: '04:00 PM'
    fill_in 'end_time', with: '09:00 PM'
    fill_in 'end_date', with: '2014-05-15'
    fill_in 'Website', with: 'www.rubyzoo.com'
    fill_in 'Description', with: 'An ruby event at the zoo'
    fill_in 'Venue details', with: 'Next to the gorillas'
    fill_in 'Tags', with: 'ruby,zoo'

    click_on 'Create Event'

    page.should have_content 'Event was successfully saved'
    page.should have_content "Please tell us more about where it's being held."
    page.should have_content 'Version Editing: Portland Zoo'

    find_field('Venue Name').value.should have_content 'Portland Zoo'

    fill_in 'Venue Name', with: 'Zoo of Portland'
    fill_in 'Full Address', with: '4001 SW Canyon Rd, Portland, OR 97221'
    fill_in 'Street address', with: '4001 SW Canyon Rd'
    fill_in 'City', with: 'Portland'
    fill_in 'State', with: 'OR'
    fill_in 'Zip Code', with: '97221'
    fill_in 'Web Link', with: 'www.portland.zoo'
    fill_in 'Email', with: 'zoo@portland.zoo'
    fill_in 'Telephone', with: '123-444-5555'

    click_on 'Update Venue'

    page.should have_content 'Venue was successfully saved'
    page.should have_content 'Ruby Zoo'
    page.should have_content 'Zoo of Portland'
    page.should have_content 'Thursday, May 15, 2014 from 4–9pm'
    page.should have_content 'Zoo of Portland 4001 SW Canyon Rd Portland, OR 97221 (map)'
    page.should have_content 'Next to the gorillas'
    page.should have_content 'Website http://www.rubyzoo.com'
    page.should have_content 'Description An ruby event at the zoo'
    page.should have_content 'Tags ruby, zoo'

    click_link 'Zoo of Portland'

    page.should have_content 'Zoo of Portland'
    page.should have_content '4001 SW Canyon Rd Portland, OR 97221 (map)'
    page.should have_content 'www.portland.zoo'
    page.should have_content 'zoo@portland.zoo'
    page.should have_content '123-444-5555'
  end

  scenario 'User begins typing a venue name' do
    create :venue, title: 'New Relic'
    create :venue, title: 'Urban Airship'

    visit '/events/new'
    find_field('Venue').native.send_keys 'urban'

    expect(page).to have_text('Urban Airship')
    expect(page).to have_no_text('New Relic')
  end
end
