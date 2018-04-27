# coding: utf-8

require 'rails_helper'
require 'login_helper'

describe 'Dialect page', js: true do
  describe 'role radio button' do
    it 'is checked on page load and controls idioms' do
      with_login do |user|
        expect(user.idioms).to be_empty
        make_larks_and_ravens_in_db(user)

        visit '/dialect'
        show_advanced_options

        # loads with correct html
        expect(page).to_not have_idiom_with('ladles', 'ladies')
        expect(page).to_not have_idiom_with('first ladle', 'first lady')
        expect(page).to_not have_idiom_with('second ladle', 'second lady')
        expect(page).to_not have_idiom_with('gentlespoons', 'gents')
        expect(page).to_not have_idiom_with('first gentlespoon', 'first gent')
        expect(page).to_not have_idiom_with('second gentlespoon', 'second gent')

        expect(page).to have_idiom_with('gentlespoons', 'larks')
        expect(page).to have_idiom_with('first gentlespoon', 'first lark')
        expect(page).to have_idiom_with('second gentlespoon', 'second lark')
        expect(page).to have_idiom_with('ladles', 'ravens')
        expect(page).to have_idiom_with('first ladle', 'first raven')
        expect(page).to have_idiom_with('second ladle', 'second raven')
        expect(page).to have_css('.glyphicon-ok', count: 6) # load with correct blinkenlight
        expect(find_field("larks-ravens")).to be_checked
        expect(find_field("gents-ladies")).to_not be_checked

        choose('ladies & gents')

        # test html
        expect(page).to have_idiom_with('ladles', 'ladies')
        expect(page).to have_idiom_with('first ladle', 'first lady')
        expect(page).to have_idiom_with('second ladle', 'second lady')
        expect(page).to have_idiom_with('gentlespoons', 'gents')
        expect(page).to have_idiom_with('first gentlespoon', 'first gent')
        expect(page).to have_idiom_with('second gentlespoon', 'second gent')
        expect(find_field("larks-ravens")).to_not be_checked
        expect(find_field("gents-ladies")).to be_checked

        # test db
        dancers = user.reload.dialect['dancers']
        expect(dancers['ladles']).to eq('ladies')
        expect(dancers['first ladle']).to eq('first lady')
        expect(dancers['second ladle']).to eq('second lady')
        expect(dancers['gentlespoons']).to eq('gents')
        expect(dancers['first gentlespoon']).to eq('first gent')
        expect(dancers['second gentlespoon']).to eq('second gent')
        expect(page).to have_css('.idiom-form')

        # test delete
        choose('ladles & gentlespoons')
        expect(page).to_not have_css('.idiom-form')
        expect(user.idioms.reload).to be_empty
      end
    end

    it 'no radios are lit when user loads page with unusual dancer idioms' do
      with_login do |user|
        FactoryGirl.create(:dancer_idiom, user: user, term: 'ladles', substitution: 'ladles chicken')
        visit '/dialect'

        expect(find_field("gentlespoons-ladles")).to_not be_checked
        expect(find_field("gents-ladies")).to_not be_checked
        expect(find_field("larks-ravens")).to_not be_checked
        expect(find_field("leads-follows")).to_not be_checked
      end
    end


    it 'ladles and gentlespoons unlights & relights when other stuff shifts underneath its feet' do
      with_login do |user|
        # ladles and gentlespoons has a different implementation path than the other express pickers
        visit '/dialect'
        show_advanced_options

        expect_pressed_radios(gentlespoons_ladles: true)

        select 'ladles'
        fill_in 'ladles-substitution', with: 'T-Rexes'

        expect(page).to have_css('.glyphicon-ok') # js wait (this was a flake elsewhere in this file, and I ended up doing a sleep there)
        expect_pressed_radios

        click_on 'delete-ladles'
        expect(page).to_not have_css('#delete-ladles') # js wait (this was a flake elsewhere in this file, and I ended up doing a sleep there)
        expect_pressed_radios(gentlespoons_ladles: true)
      end
    end

    it 'role radios unlight & relight when other stuff shifts underneath their feet' do
      with_login do |user|
        expect(user.idioms).to be_empty
        make_larks_and_ravens_in_db(user)

        visit '/dialect'
        show_advanced_options

        # near as I can tell, there's no way to do a waiting-expect a radio button to be checked.
        # I REALLY tried to find something like: expect(page).to have_css('#larks-ravens[checked]')
        sleep(0.5)
        expect_pressed_radios(larks_ravens: true)

        fill_in 'ladles-substitution', with: 'crows'
        sleep(0.5)
        expect(page).to have_css('.glyphicon-ok') # js wait
        expect_pressed_radios

        fill_in 'ladles-substitution', with: 'ravens'
        sleep(0.5)
        expect(page).to have_css('.glyphicon-ok') # js wait
        expect_pressed_radios(larks_ravens: true)

        click_on 'delete-ladles'
        expect(page).to_not have_css('#delete-ladies') # js wait
        expect_pressed_radios
      end
    end
  end

  describe 'gyre' do

    it "'substitute...' button and dialog work" do
      with_login do |user|
        visit '/dialect'
        show_advanced_options
        expect(page).to have_text('currently using: gyre')
        click_button('substitute...')
        fill_in 'gyre-dialog-substitution', with: 'gazey'
        expect(page).to have_text("Substitute for")
        click_button('Save')
        expect(page).to have_idiom_with('gyre', 'gazey')
        expect(page).to_not have_text("Substitute for")
        expect(page).to have_text('currently using: gazey')
      end
    end
  end

  describe 'idiom list' do

    it 'create move' do
      with_login do |user|
        visit '/dialect'
        show_advanced_options
        select 'swing'
        fill_in 'swing-substitution', with: 'swong' # js wait
        expect(find('.new-move-idiom').value).to eq('') # select box doesn't stick on 'swing'
        expect(page).to have_css('.glyphicon-ok')
        expect(user.idioms.length).to eq(1)
        expect(user.idioms.first.term).to eq('swing')
        expect(user.idioms.first.substitution).to eq('swong')
      end
    end

    it 'create dancer' do
      with_login do |user|
        visit '/dialect'
        show_advanced_options
        select 'neighbors'
        fill_in 'neighbors-substitution', with: 'buddies' # js wait
        expect(find('.new-dancers-idiom').value).to eq('') # select box doesn't stick on 'neighbors'
        expect(page).to have_css('.glyphicon-ok')
        expect(user.idioms.length).to eq(1)
        expect(user.idioms.first.term).to eq('neighbors')
        expect(user.idioms.first.substitution).to eq('buddies')
      end
    end

    describe '[x]' do

      it 'works on new idiom' do
        with_login do |user|
          visit '/dialect'
          show_advanced_options
          select 'gate'
          expect(page).to have_idiom_with('gate', 'gate')
          click_on 'delete-gate'
          expect(page).to_not have_idiom_with('gate', 'gate')
          user.reload
          expect(user.idioms.length).to eq(0)
        end
      end

      it 'works on existing idiom' do
        with_login do |user|
          idiom = FactoryGirl.create(:move_idiom, user: user, term: 'gate', substitution: 'flip')
          visit '/dialect'
          show_advanced_options
          expect(page).to have_idiom(idiom)
          click_on 'delete-gate'
          expect(page).to_not have_idiom(idiom)
          user.reload
          expect(user.idioms.length).to eq(0)
        end
      end
    end
  end

  describe 'idiom adder select menus' do
    it 'disable items that are already on the page' do
      with_login do |user|
        visit '/dialect'
        show_advanced_options
        select('gate')
        expect(page).to have_css('option[value=gate][disabled]')
      end
    end

    it 'reenable stored terms that are deleted' do
      with_login do |user|
        FactoryGirl.create(:move_idiom, user: user, term: 'gate', substitution: 'flip')
        visit '/dialect'
        show_advanced_options
        expect(page).to have_css('option[value=gate][disabled]')
        click_button('delete-gate')
        expect(page).to have_css('option[value=gate]')
        expect(page).to_not have_css('option[value=gate][disabled]')
      end
    end

    it 'reenable new terms that are subsequently deleted' do
      with_login do |user|
        visit '/dialect'
        show_advanced_options
        select('gate')
        expect(page).to have_css('option[value=gate][disabled]')
        click_button('delete-gate')
        expect(page).to have_css('option[value=gate]')
        expect(page).to_not have_css('option[value=gate][disabled]')
      end
    end
  end

  it 'loads help on logging in when accessed without login' do
    visit '/dialect'
    expect(current_path).to eq(new_user_session_path)
  end

  it 'Restore Default Dialect button works' do
    with_login do |user|
      dancer_idiom = FactoryGirl.create(:dancer_idiom, user: user, term: 'gentlespoons', substitution: 'brontosauruses')
      move_idiom = FactoryGirl.create(:move_idiom, user: user, term: 'allemande', substitution: 'almond')

      expect(user.idioms).to be_present

      visit '/dialect'
      show_advanced_options

      click_button('Restore Default Dialect')
      # automatically clicks confirm!?

      expect(page).to_not have_field('gentlespoons-substitution', with: 'brontosauruses') # js wait, masking mysterious bug
      expect(page).to_not have_idiom(dancer_idiom)
      expect(page).to_not have_idiom(move_idiom)
      expect(user.reload.idioms).to be_empty
    end
  end

  describe 'Advanced show button' do
    it 'hides and shows idiom editors' do
      with_login do |user|
        idiom = FactoryGirl.create(:move_idiom, user: user, term: 'slice', substitution: 'yearn')
        visit '/dialect'
        expect(page).to_not have_idiom(idiom)
        expect(page).to have_css('.dialect-advanced-toggle-button')
        expect(page).to_not have_css('.dialect-advanced-toggle-button.btn-primary')
        expect(page).to_not have_css('.new-move-idiom')
        expect(page).to_not have_css('.new-dancers-idiom')
        click_button('show...')
        expect(page).to have_css('.dialect-advanced-toggle-button.btn-primary')
        expect(page).to have_css('.new-move-idiom')
        expect(page).to have_css('.new-dancers-idiom')
        expect(page).to have_idiom(idiom)
      end
    end
  end

  def show_advanced_options
    click_button('show...')
    expect(page).to have_css('.dialect-advanced-toggle-button.btn-primary') # js wait for completion
  end

  def expect_pressed_radios(gentlespoons_ladles: false,
                            gents_ladies: false,
                            larks_ravens: false,
                            leads_follows: false)

    if gentlespoons_ladles
      expect(find_field("gentlespoons-ladles")).to be_checked
    else
      expect(find_field("gentlespoons-ladles")).to_not be_checked
    end

    if gents_ladies
      expect(find_field("gents-ladies")).to be_checked
    else
      expect(find_field("gents-ladies")).to_not be_checked
    end

    if larks_ravens
      expect(find_field("larks-ravens")).to be_checked
    else
      expect(find_field("larks-ravens")).to_not be_checked
    end

    if leads_follows
      expect(find_field("leads-follows")).to be_checked
    else
      expect(find_field("leads-follows")).to_not be_checked
    end
  end

  def make_larks_and_ravens_in_db(user)
    FactoryGirl.create(:dancer_idiom, user: user, term: 'gentlespoons', substitution: 'larks')
    FactoryGirl.create(:dancer_idiom, user: user, term: 'first gentlespoon', substitution: 'first lark')
    FactoryGirl.create(:dancer_idiom, user: user, term: 'second gentlespoon', substitution: 'second lark')
    FactoryGirl.create(:dancer_idiom, user: user, term: 'ladles', substitution: 'ravens')
    FactoryGirl.create(:dancer_idiom, user: user, term: 'first ladle', substitution: 'first raven')
    FactoryGirl.create(:dancer_idiom, user: user, term: 'second ladle', substitution: 'second raven')
  end
end