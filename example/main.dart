// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_workday/otel_workday.dart';

/// Traces Workday calls with OpenTelemetry.
///
/// `otel_workday` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Workday call in
/// [tracedWorkday]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'workday-example');

  // Wraps a Workday API call in a CLIENT span.
  final workdayId = await tracedWorkday<String>(
    operation: 'raas.run',
    tenant: 'example',
    protocol: 'example',
    invoke: () async {
      // Make the Workday call here, then report what it returned.
      const id = 'workday_8f3a2c';
      return const WorkdayCallResult(
          value: id,
          result: WorkdayResult(
              total: 1,
              itemCount: 3,
              tenant: 'acme1',
              protocol: 'rest',
              reportName: 'example',
              reportFormat: 'json',
              workerType: 'Employee',
              businessProcessStatus: 'Successfully_Completed',
              requestId: 'WD-Request-Id',
              statusCode: 200));
    },
  );
  OTelLog.info('tracedWorkday raas.run returned $workdayId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutWorkdayInstrumentationAsync.
  await runWithoutWorkdayInstrumentationAsync(
    () => tracedWorkday<String>(
      operation: 'raas.run',
      tenant: 'example',
      protocol: 'example',
      invoke: () async {
        const id = 'workday_8f3a2c';
        return const WorkdayCallResult(
            value: id,
            result: WorkdayResult(
                total: 1,
                itemCount: 3,
                tenant: 'acme1',
                protocol: 'rest',
                reportName: 'example',
                reportFormat: 'json',
                workerType: 'Employee',
                businessProcessStatus: 'Successfully_Completed',
                requestId: 'WD-Request-Id',
                statusCode: 200));
      },
    ),
  );

  await OTel.shutdown();
}
