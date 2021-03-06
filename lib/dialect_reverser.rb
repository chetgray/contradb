# service object which translates strings full of dialect substitutions back into terms

class DialectReverser
  attr_reader :dialect

  def initialize(dialect)
    @dialect = dialect
    @inverted_hash = make_inverted_hash
    @regexp = make_regexp
  end

  def reverse(string)           # really string-or-falsey
    if string.present?
      string.gsub(regexp) do |match|
        term = inverted_hash.fetch(match.downcase) {|match_downcase|
          # go fish in case-insensitive, %S stripping "hash lookup" mode
          key = inverted_hash.keys.find {|k| strip_percent_s(k).downcase == match_downcase}
          key or raise("failed to find #{match.inspect} in #{inverted_hash.keys.inspect}")
          inverted_hash.fetch(key)
        }
        substitution = dialect_ref(term)
        apply_caps_transition(match, term, substitution)
      end
    else
      ''
    end
  end

  private
  attr_reader :regexp
  attr_reader :inverted_hash

  def make_inverted_hash
    alist = dialect.fetch('moves').to_a + dialect.fetch('dancers').to_a
    alist = alist.sort do |term_sub_a, term_sub_b|
      a = term_sub_a[1]
      b = term_sub_b[1]
      diff = b.length - a.length
      diff.zero? ? b <=> a : diff
    end
    alist.map(&:reverse).to_h
  end

  def make_regexp
    if inverted_hash.length.zero?
      /.^/                      # matches nothing
    else
      /\b(#{inverted_hash.keys.map {|s| Regexp.escape(strip_percent_s(s))}.join('|')})\b/i
    end
  end

  def strip_percent_s(substitution)
    substitution.gsub(/%S/, '').strip
  end

  def dialect_ref(term)
    substitution = dialect.dig('dancers', term) || dialect.dig('moves', term)
    substitution.gsub('%S', '')
  end

  def apply_caps_transition(substitution_as_typed, term, substitution)
    if has_upper_case?(term)
      term
    elsif more_capitalized_than?(substitution_as_typed, substitution)
      term.capitalize
    else
      term
    end
  end

  def more_capitalized_than?(left, right)
    has_upper_case?(left) && !has_upper_case?(right)
  end

  def has_upper_case?(x)
    x =~ ANY_UPPER_CASE_REGEXP
  end

  ANY_UPPER_CASE_REGEXP = /[[:upper:]]/
end
