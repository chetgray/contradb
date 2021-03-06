require 'rails_helper'
require 'support/scrutinize_layout'

describe 'Creating user from welcome page' do
  let(:user) {FactoryGirl.create(:user, news_email: true)}

  it "shows a table of users" do
    user
    visit users_path
    scrutinize_layout page
    expect(page).to have_link(user.name, href: user_path(user))
    # this test is weak and could certainly test more rows...
  end

  describe "newsletter mailto" do
    it "doesn't show when not admin" do
      user
      visit users_path
      expect(page).to_not have_link('write a newsletter')
    end

    it "shows when admin" do
      user
      user2 = FactoryGirl.create(:user, news_email: true)
      _private_user = FactoryGirl.create(:user, news_email: false)
      with_login(admin: true) do |admin|
        bccs = User.where(news_email: true).map(&:email).join('%2C').gsub('@','%40')
        visit users_path
        expect(page).to have_link('write a newsletter...', href: "mailto:#{admin.email}?bcc=#{bccs}")
      end
    end
  end
end
