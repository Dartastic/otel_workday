// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_workday/otel_workday.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_workday-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('raas.run records protocol + report + format', () async {
    await tracedWorkday<String>(
      operation: 'raas.run',
      tenant: 'acme1',
      protocol: 'raas',
      invoke: () async => const WorkdayCallResult(
        value: 'ok',
        result: WorkdayResult(
          tenant: 'acme1',
          protocol: 'raas',
          reportName: 'Active_Workers',
          reportFormat: 'json',
          total: 4321,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('workday raas.run')!);
    expect(a['workday.tenant'], 'acme1');
    expect(a['workday.protocol'], 'raas');
    expect(a['workday.raas.report'], 'Active_Workers');
    expect(a['workday.total'], 4321);
  });

  test('business process Failed sets span error', () async {
    await tracedWorkday<String>(
      operation: 'workers.hire',
      invoke: () async => const WorkdayCallResult(
        value: 'ok',
        result: WorkdayResult(
          businessProcessStatus: 'Failed',
          workerType: 'Employee',
        ),
      ),
    );
    expect(
      spans.findSpanByName('workday workers.hire')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutWorkdayInstrumentationAsync(() async {
      await tracedWorkday<String>(
        operation: 'workers.list',
        invoke: () async => const WorkdayCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('workday '), isEmpty);
  });
}
