import 'dart:async';

Future<void> simulateBatchCommit() async {
  // Simulate network latency for a commit
  await Future.delayed(Duration(milliseconds: 100));
}

void main() async {
  int numBatches = 10;

  print('Starting baseline benchmark (Sequential)...');
  Stopwatch sw = Stopwatch()..start();
  for (int i = 0; i < numBatches; i++) {
    await simulateBatchCommit();
  }
  sw.stop();
  final sequentialTime = sw.elapsedMilliseconds;
  print('Sequential time: ${sequentialTime}ms');

  print('Starting optimized benchmark (Concurrent)...');
  sw.reset();
  sw.start();
  List<Future<void>> futures = [];
  for (int i = 0; i < numBatches; i++) {
    futures.add(simulateBatchCommit());
  }
  await Future.wait(futures);
  sw.stop();
  final concurrentTime = sw.elapsedMilliseconds;
  print('Concurrent time: ${concurrentTime}ms');

  if (sequentialTime > 0) {
    final speedup = (sequentialTime - concurrentTime) / sequentialTime * 100;
    print('Speedup: ${speedup.toStringAsFixed(2)}%');
  }
}
