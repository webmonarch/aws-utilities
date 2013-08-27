# Substitutes all path separators in the given string with the native path separator
def sep(path)
  path.gsub(File::SEPARATOR, File::ALT_SEPARATOR || File::SEPARATOR)
end