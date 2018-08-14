require 'set'
require 'search_match'

class DanceDatatable < AjaxDatatablesRails::Base

  def_delegators :@view, :link_to, :dance_path, :choreographer_path, :user_path

  def view_columns
    # Declare strings in this format: ModelName.column_name
    # or in aliased_join_table.column_name format
    @view_columns ||= {
      title: { source: "Dance.title" },
      choreographer_name: { source: "Choreographer.name" },
      formation: { source: "Dance.start_type", searchable: false},
      hook: { source: "Dance.hook", searchable: false},
      user_name: { source: "User.name" },
      created_at: { source: "Dance.created_at", searchable: false, orderable: true },
      updated_at: { source: "Dance.updated_at", searchable: false, orderable: true },
      published: { source: "Dance.publish", searchable: false, orderable: true }
    }
  end

  def data
    records.map do |dance|
      {
        title: link_to(dance.title, dance_path(dance)),
        choreographer_name: link_to(dance.choreographer.name, choreographer_path(dance.choreographer)),
        formation: dance.start_type,
        hook: JSLibFigure.string_in_dialect(dance.hook, dialect),
        user_name: link_to(dance.user.name, user_path(dance.user)),
        created_at: dance.created_at.strftime('%Y-%m-%d'),
        updated_at: dance.updated_at.strftime('%Y-%m-%d'),
        published: dance.publish ? 'Published' : nil
      }
    end
  end

  private

  def get_raw_records
    filter = DanceDatatable.hash_to_array(figure_query)
    dances = Dance.readable_by(user).to_a
    dances = DanceDatatable.filter_dances(dances, filter)
    Dance.where(id: dances.map(&:id)).includes(:choreographer, :user).references(:choreographer, :user)
  end

  def user
    @user ||= options[:user]
  end

  def figure_query
    @figure_query ||= options[:figure_query]
  end

  def dialect
    @dialect ||= options[:dialect]
  end

  # ==== These methods represent the basic operations to perform on records
  # and feel free to override them

  # def filter_records(records)
  # end

  # def sort_records(records)
  # end

  # def paginate_records(records)
  # end

  # ==== Insert 'presenter'-like methods below if necessary


  private

  def self.filter_dances(dances, filter)
    raise "filter must be an array, but got #{filter.inspect} of class #{filter.class}" unless filter.is_a? Array
    dances.select {|dance| matching_figures?(filter, dance)}
  end

  def self.matching_figures?(filter, dance)
    matching_figures(filter, dance) != nil
  end

  # These functions return either nil (failure) or a set of SearchMatches
  #
  # The set may have zero elements, which means a successful match, but no specific index matches all criteria.
  # To see an example of that, think of the dance (and (figure 'chain') (figure 'right left through')), which can
  # match because it has a chain, and a right left through, but no figure satisfies both of those exactly.
  #
  # The set must always be sorted

  def self.matching_figures(filter, dance)
    operator = filter.first
    fn = :"matching_figures_for_#{operator.gsub(' ', '_')}"
    raise "#{operator.inspect} is not a valid operator in #{filter.inspect}" unless self.respond_to?(fn, true)
    matches = send(fn, filter, dance)
    # puts "matching_figures #{dance.title} #{filter.inspect} = #{matches.inspect}"
    matches
  end

  def self.matching_figures_for_figure(filter, dance)
    filter_move = filter[1]
    if '*' == filter_move              # wildcard
      all_figures_match(dance)
    else
      formals = JSLibFigure.is_move?(filter_move) ? JSLibFigure.formal_parameters(filter_move) : []
      nfigures = dance.figures.length
      search_matches = Set[]
      indicies = dance.figures.each_with_index do |figure, figure_index|
        actuals = JSLibFigure.parameter_values(figure)
        filter_canonical = JSLibFigure.de_alias_move(filter_move)
        filter_is_alias = filter_canonical != filter_move
        param_filters = filter.drop(2)
        param_filters = JSLibFigure.alias_filter(filter_move) if filter_is_alias && param_filters.empty?
        matches = JSLibFigure.move(figure) == filter_canonical &&
                  param_filters.each_with_index.all? {|param_filter, i| param_passes_filter?(formals[i], actuals[i], param_filter)}
        matches ? figure_index : nil
        search_matches << SearchMatch.new(figure_index, nfigures) if matches
      end
      search_matches.present? ? search_matches : nil
    end
  end

  def self.param_passes_filter?(formal_param, dance_param, param_filter)
    if JSLibFigure.parameter_uses_chooser(formal_param, 'chooser_text')
      # substring search
      keywords = param_filter.split(' ')
      keywords.any? {|keyword| dance_param.include?(keyword)}
    elsif JSLibFigure.parameter_uses_chooser(formal_param, 'chooser_half_or_full')
      param_filter === '*' || param_filter.to_f === dance_param.to_f
    elsif JSLibFigure.formal_param_is_dancers(formal_param)
      param_filter === '*' || JSLibFigure.dancers_category(dance_param) === param_filter
    else
      # asterisk always matches, or exact match
      param_filter === '*' || param_filter.to_s === dance_param.to_s
    end
  end

  def self.matching_figures_for_no(filter, dance)
    subfilter = filter[1]
    if matching_figures(subfilter, dance)
      nil
    else
      all_figures_match(dance.figures.length)
    end
  end

  def self.matching_figures_for_all(filter, dance)
    subfilter = filter[1]
    matches = matching_figures(subfilter, dance)
    if dance.figures.length.times.all? {|i| matches.any? {|search_match| search_match.include?(i)}}
      matches
    else
      nil
    end
  end

  def self.matching_figures_for_or(filter, dance)
    subfilters = filter.drop(1)
    nfigures = dance.figures.length
    matches = Set[]
    subfilters.each do |subfilter|
      matches |= matching_figures(subfilter, dance) || Set[]
      return matches if matches.length == nfigures
    end
    matches.present? ? matches : nil
  end

  def self.matching_figures_for_and(filter, dance)
    nfigures = dance.figures.length
    subfilters = filter.drop(1)
    return Set[] if subfilters.empty? # should maybe return the infinitely large set of all searchmatches instead
    matches = subfilters.map {|subfilter| matching_figures(subfilter, dance) or return nil}
    m = matches.first
    matches.drop(1).each {|x| m &= x} # naive intersection
    m
  end

  # anything but is mainly useful when paired with then
  def self.matching_figures_for_anything_but(filter, dance)
    subfilter = filter[1]
    figures = all_figure_indicies(dance) - (matching_figures(subfilter, dance) || [])
    figures.present? ? figures.sort : nil
  end

  def self.matching_figures_for_then(filter, dance)
    figures_count = dance.figures.count
    going_concerns = all_empty_matches(figures_count)
    subfilters = filter.drop(1)
    subfilters.each do |subfilter|
      m = matching_figures(subfilter, dance)
      new_concerns = Set[]
      going_concerns.each do |search_match_head|
        m.each do |search_match_tail|
          new_concern = search_match_head.abut(search_match_tail)
          new_concerns << new_concern if new_concern
        end
      end
      going_concerns = new_concerns
      return nil unless going_concerns.present?
    end
    going_concerns
  end

  def self.all_empty_matches(nfigures)
    Set.new(nfigures.times.map{|i| SearchMatch.new(i, nfigures, count: 0)})
  end

  def self.all_figures_match(nfigures)
    Set.new(nfigures.times.map{|i| SearchMatch.new(i, nfigures)})
  end

  # obsolete?
  def self.all_figure_indicies(dance)
    [*0...dance.figures.count]
  end

  def self.hash_to_array(h)
    h = h.to_h if h.instance_of?(ActionController::Parameters)
    if !(h.instance_of?(Hash) || h.instance_of?(ActiveSupport::HashWithIndifferentAccess))
      h
    elsif !h['faux_array']
      h
    else
      i = 0
      arr = []
      while h.key?(i.to_s)
        arr << hash_to_array(h[i.to_s])
        i += 1
      end
      arr
    end
  end

  # given a set of search matches, return a set of new search matches with count: 1 search matches for every index anywhere in the set
  def self.dice_search_matches(set)
    Set.new(
      set.map {|search_match| search_match.map {|i| SearchMatch.new(i, search_match.nfigures)}}.flatten)
  end
end
