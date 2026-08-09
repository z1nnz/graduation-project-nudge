import '../models/activity_ledger.dart';
import '../models/room_activity_session.dart';
import 'cloud_activity_ledger_gateway.dart';

abstract interface class RoomActivitySessionLedgerGateway {
  Future<ActivityRecordResult> record({
    required ActivityEvidence evidence,
    required RoomActivitySession session,
  });
}

class CloudRoomActivitySessionLedgerGateway
    implements RoomActivitySessionLedgerGateway {
  CloudRoomActivitySessionLedgerGateway({CloudActivityLedgerGateway? gateway})
    : _gateway = gateway ?? CloudActivityLedgerGateway.firebase();

  final CloudActivityLedgerGateway _gateway;

  @override
  Future<ActivityRecordResult> record({
    required ActivityEvidence evidence,
    required RoomActivitySession session,
  }) {
    return _gateway.recordActivity(evidence, roomSession: session.toJson());
  }
}
