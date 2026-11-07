// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_workday_suppression.dart';

const _tracerName = 'dartastic_otel_libs_workday';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class WorkdayResult {
  /// Creates a result.
  const WorkdayResult({
    this.total,
    this.itemCount,
    this.tenant,
    this.protocol,
    this.reportName,
    this.reportFormat,
    this.workerType,
    this.businessProcessStatus,
    this.requestId,
    this.statusCode,
  });

  /// `Total` returned by Workday paging.
  final int? total;

  /// `Data.length` for REST collections.
  final int? itemCount;

  /// Customer's Workday tenant id (e.g. `acme1`) — multi-tenant SaaS,
  /// drives endpoint + auth.
  final String? tenant;

  /// `rest` / `soap` / `raas` — Workday exposes three call shapes,
  /// each with very different latency profiles.
  final String? protocol;

  /// RaaS report name when protocol == raas.
  final String? reportName;

  /// `json` / `csv` / `xlsx` / `xml`.
  final String? reportFormat;

  /// `Employee` / `Contingent_Worker` — distinct workflows.
  final String? workerType;

  /// `Successfully_Completed` / `In_Progress` / `Failed` / `Denied`.
  final String? businessProcessStatus;

  /// `WD-Request-Id` if present.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class WorkdayCallResult<T> {
  /// Creates a call result.
  const WorkdayCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final WorkdayResult? result;
}

/// Wraps a Workday API call in a CLIENT span. [operation] is one of
/// `workers.list`, `workers.get`, `workers.hire`, `workers.terminate`,
/// `time_off.requests.list`, `time_off.requests.submit`,
/// `compensation.list`, `compensation.changes.submit`,
/// `business_processes.events.list`, `business_processes.status`,
/// `raas.run`, `integration.systems.list`.
Future<T> tracedWorkday<T>({
  required String operation,
  required Future<WorkdayCallResult<T>> Function() invoke,
  String? tenant,
  String? protocol,
}) async {
  if (workdayInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'workday',
    'rpc.method': operation,
    'workday.operation': operation,
  };
  if (tenant != null) m['workday.tenant'] = tenant;
  if (protocol != null) m['workday.protocol'] = protocol;

  final span = _tracer().startSpan(
    'workday $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.total != null) {
        extras.add(OTelAPI.attributeInt('workday.total', r.result!.total!));
      }
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'workday.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.tenant != null) {
        extras.add(OTelAPI.attributeString(
          'workday.tenant',
          r.result!.tenant!,
        ));
      }
      if (r.result!.protocol != null) {
        extras.add(OTelAPI.attributeString(
          'workday.protocol',
          r.result!.protocol!,
        ));
      }
      if (r.result!.reportName != null) {
        extras.add(OTelAPI.attributeString(
          'workday.raas.report',
          r.result!.reportName!,
        ));
      }
      if (r.result!.reportFormat != null) {
        extras.add(OTelAPI.attributeString(
          'workday.raas.format',
          r.result!.reportFormat!,
        ));
      }
      if (r.result!.workerType != null) {
        extras.add(OTelAPI.attributeString(
          'workday.worker.type',
          r.result!.workerType!,
        ));
      }
      if (r.result!.businessProcessStatus != null) {
        extras.add(OTelAPI.attributeString(
          'workday.business_process.status',
          r.result!.businessProcessStatus!,
        ));
        if (r.result!.businessProcessStatus == 'Failed' ||
            r.result!.businessProcessStatus == 'Denied') {
          span.setStatus(
            SpanStatusCode.Error,
            'Workday BP ${r.result!.businessProcessStatus}',
          );
        }
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'workday.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Workday HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
