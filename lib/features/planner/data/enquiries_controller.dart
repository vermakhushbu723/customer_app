import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/list_store.dart';
import '../../../core/storage/local_store.dart';
import '../domain/ice_plan.dart';

class EnquiriesController extends ListStore<BulkEnquiry> {
  @override
  String get key => 'bulk_enquiries';
  @override
  String get path => '/customer/enquiries';
  @override
  BulkEnquiry fromJson(Json json) => BulkEnquiry.fromJson(json);
  @override
  Json toJson(BulkEnquiry item) => item.toJson();

  Future<void> add(BulkEnquiry enquiry) async {
    if (!useFakeBackend) {
      final body = await api.post('/customer/enquiries', enquiry.toJson());
      save([BulkEnquiry.fromJson(body as Map<String, dynamic>), ...state]);
      return;
    }
    save([enquiry, ...state]);
  }
}

final enquiriesProvider = NotifierProvider<EnquiriesController, List<BulkEnquiry>>(EnquiriesController.new);
