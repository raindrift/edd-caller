def normalize_number value
  if value !~ /^sip/
    value.gsub!(/\D/, '')
    value = "1#{value}" if value !~ /^1/
    value = "+#{value}"
  end
  value
end

def strip_number value
  value.gsub(/^\+/, '')
end

def valid_us_pots_number? value
  value =~ /^\+1\d{10}$/
end
