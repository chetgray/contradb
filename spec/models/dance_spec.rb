# coding: utf-8
require 'rails_helper'

RSpec.describe Dance, type: :model do
  it ':dance_with_a_custom factory produces dances with a custom figure' do
    dance = FactoryGirl.build(:dance_with_a_custom, custom_text: 'wombats')
    expect(dance).to be_valid
    expect(dance.figures.first['parameter_values'].first).to eq('wombats')
  end

  it "'alphabetical' scope returns dances in case-insensitive alphabetical order" do
    titles = ["AAAA","DDDD","cccc","BBBB"]
    titles.each {|title| FactoryGirl.create :dance, title: title }
    expect(Dance.alphabetical.pluck(:title)).to eq ["AAAA","BBBB","cccc","DDDD"]
  end

  describe 'memoizing figures' do
    it 'caches' do
      dance = FactoryGirl.build(:dance)
      figures = dance.figures
      expect(dance.figures).to be(figures)
    end

    it 'cache invalidates on figures=' do
      dance = FactoryGirl.build(:dance)
      dance2 = FactoryGirl.build(:box_the_gnat_contra)
      figures = dance.figures
      dance.figures = dance2.figures
      expect(dance.figures).to_not eq(figures)
      expect(dance.figures).to be(dance2.figures)
    end

    it 'cache invalidates on figures_json=' do
      dance = FactoryGirl.build(:dance)
      dance2 = FactoryGirl.build(:box_the_gnat_contra)
      figures = dance.figures
      dance.figures_json = dance2.figures_json
      expect(dance.figures).to_not eq(figures)
      expect(dance.figures).to eq(dance2.figures)
    end
  end

  describe "permissions" do
    let! (:admonsterator) { FactoryGirl.create(:user, admin: true) }
    let (:user_a) { FactoryGirl.create(:user) }
    let (:user_b) { FactoryGirl.create(:user) }
    let! (:dance_a0) { FactoryGirl.create(:dance, user: user_a, title: "dance a0", publish: :off) }
    let! (:dance_a1) { FactoryGirl.create(:dance, user: user_a, title: "dance a1", publish: :sketchbook) }
    let! (:dance_a2) { FactoryGirl.create(:dance, user: user_a, title: "dance a2", publish: :all) }
    let! (:dance_b0) { FactoryGirl.create(:dance, user: user_b, title: "dance b0", publish: :off) }
    let! (:dance_b1) { FactoryGirl.create(:dance, user: user_b, title: "dance b1", publish: :sketchbook) }
    let! (:dance_b2) { FactoryGirl.create(:dance, user: user_b, title: "dance b2", publish: :all) }
    let (:dances) { [dance_a0, dance_a1, dance_a2, dance_b0, dance_b1, dance_b2] }

    describe '#readable?' do
      it "with unspecified user returns published_sketchbook or published_all dances" do
        expect(dances.map(&:readable?)).to eq([false,true,true,false,true,true])
      end

      it "with user returns their dances and published_sketchbook/published_all dances" do
        expect(dances.map {|d| d.readable?(user: user_a)}).to eq([true,true,true,false,true,true])
      end

      it "with admin returns all dances" do
        expect(dances.map {|d| d.readable?(user: admonsterator)}).to eq(Array.new(6, true))
      end
    end

    describe '#searchable?' do
      it "with user unspecified returns published_all? dances" do
        expect(dances.map(&:searchable?)).to eq([false,false,true,false,false,true])
      end

      it "with user returns their dances and published_all dances" do
        expect(dances.map {|d| d.searchable?(user: user_a)}).to eq([true,true,true,false,false,true])
      end

      it "with admin returns all dances" do
        expect(dances.map {|d| d.searchable?(user: admonsterator)}).to eq(Array.new(6, true))
      end

      it "with no user but sketchbook: true returns published_all? & published_sketchbook? dances" do
        expect(dances.map {|d| d.searchable?(sketchbook: true)}).to eq([false,true,true,false,true,true])
      end
    end

    describe "'readable_by' scope" do
      it "if not passed a user just returns published_sketchbook and published_all dances" do
        expect(Dance.readable_by(nil).pluck(:title).sort).to eq(['dance a1', 'dance a2', 'dance b1', 'dance b2'])
      end

      it "if passed a user, only returns published_sketchbook dances, or published_all dances, or dances of that user" do
        expect(Dance.readable_by(user_b).pluck(:title).sort).to eq(['dance a1', 'dance a2', 'dance b0', 'dance b1', 'dance b2'])
      end

      it "if passed an admin, returns all dances" do
        expect(Dance.readable_by(admonsterator).pluck(:title).sort).to eq(dances.map(&:title))
      end
    end

    describe "'searchable_by' scope" do
      it "if not passed a user returns published: all dances" do
        expect(Dance.searchable_by(nil).pluck(:title).sort).to eq(['dance a2', 'dance b2'])
      end

      it "if passed a user, only returns published: all dances, or dances of that user" do
        expect(Dance.searchable_by(user_b).pluck(:title).sort).to eq(['dance a2', 'dance b0', 'dance b1', 'dance b2'])
      end

      it "if passed an admin, returns all dances" do
        expect(Dance.searchable_by(admonsterator).pluck(:title).sort).to eq(dances.map(&:title))
      end

      it "if passed the optional sketchbook: true argument, returns both :sketchbook and :all dances" do
        expect(Dance.searchable_by(nil, sketchbook: true).pluck(:title).sort).to eq(['dance a1', 'dance a2', 'dance b1', 'dance b2'])
      end
    end
  end

  describe '#aliases' do
    it 'works' do
      expect(FactoryGirl.build(:box_the_gnat_contra).aliases).to eq(['box the gnat',
                                                                     'swat the flea',
                                                                     'swing',
                                                                     'allemande',
                                                                     'swing',
                                                                     'right left through',
                                                                     'chain'])
    end

    it "passes 'empty figure' through as nil" do
      expect(FactoryGirl.build(:dance_with_empty_figure).aliases).to eq(['swing', nil])
    end
  end

  describe "#moves_that_precede_move" do
    it 'works' do
      dance = FactoryGirl.build(:box_the_gnat_contra)
      expect(dance.moves_that_precede_move('swat the flea')).to eq(Set.new(['box the gnat']))
    end

    it "glosses over 'empty figure'" do
      dance = FactoryGirl.build(:dance_with_empty_figure)
      expect(dance.moves_that_precede_move('swing')).to eq(Set.new(['swing']))
    end
  end

  describe "#moves_that_follow_move" do
    it 'works' do
      dance = FactoryGirl.build(:box_the_gnat_contra)
      expect(dance.moves_that_follow_move('box the gnat')).to eq(Set.new(['swat the flea']))
    end

    it "glosses over 'empty figure'" do
      dance = FactoryGirl.build(:dance_with_empty_figure)
      expect(dance.moves_that_follow_move('swing')).to eq(Set.new(['swing']))
    end
  end

  it '#set_text_to_dialect' do
    dance = FactoryGirl.build(:dance_with_a_custom,
                              custom_text: 'custom allemande gentlespoons custom',
                              figure_note: 'figure-note allemande figure-note',
                              preamble: 'preamble allemande preamble',
                              hook: 'hook allemande hook',
                              notes: 'dance-notes allemande dance-notes')
    dance.set_text_to_dialect(JSLibFigure.test_dialect)
    expect(JSLibFigure.parameter_values(dance.figures.first).first).to eq('custom almond larks custom')
    expect(JSLibFigure.note(dance.figures.first)).to eq('figure-note almond figure-note')
    expect(dance.preamble).to eq('preamble almond preamble')
    expect(dance.hook).to eq('hook almond hook')
    expect(dance.notes).to eq('dance-notes almond dance-notes')
  end

  describe 'tags' do
    let (:dut) {FactoryGirl.create(:dut)}

    it '#duts association' do
      expect(dut.dance.duts.to_a).to eq([dut])
    end

    it '#tags association' do
      expect(dut.dance.tags.to_a).to eq([dut.tag])
    end
  end
end
