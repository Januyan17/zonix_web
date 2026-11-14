import 'package:flutter/material.dart';
import 'package:zonixweb/features/history_requests/models/history_request.dart';
import 'package:zonixweb/features/history_requests/services/history_request_service.dart';
import 'package:zonixweb/features/history_requests/widgets/history_request_tile.dart';

class HistoryRequestList extends StatelessWidget {
  const HistoryRequestList({
    super.key,
    required this.requests,
    required this.service,
    required this.onUpdated,
  });

  final List<HistoryRequest> requests;
  final HistoryRequestService service;
  final ValueChanged<HistoryRequest> onUpdated;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < requests.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            HistoryRequestTile(
              key: ValueKey(requests[i].ref?.path ?? i),
              request: requests[i],
              service: service,
              onUpdated: onUpdated,
            ),
          ],
        ],
      ),
    );
  }
}
