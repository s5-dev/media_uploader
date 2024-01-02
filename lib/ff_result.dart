class FFResult {
  final int exitCode;
  final String stdout;

  FFResult({
    required this.exitCode,
    required this.stdout,
  });

  @override
  toString() => 'FFResult{$exitCode, $stdout}';
}
