String pluralize(String word, {String? plural}) => plural ?? "${word}s";

String singular(String word, {String? singular}) =>
    singular ?? word.substring(0, word.length - 1);
