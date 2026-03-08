import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class SystemConfigState {
  final bool multiCompany;
  final bool multiLocation;
  final bool isLoading;
  const SystemConfigState({this.multiCompany = false, this.multiLocation = false, this.isLoading = false});
  SystemConfigState copyWith({bool? multiCompany, bool? multiLocation, bool? isLoading}) =>
      SystemConfigState(
        multiCompany: multiCompany ?? this.multiCompany,
        multiLocation: multiLocation ?? this.multiLocation,
        isLoading: isLoading ?? this.isLoading,
      );
}

class SystemConfigNotifier extends StateNotifier<SystemConfigState> {
  final Ref _ref;
  SystemConfigNotifier(this._ref) : super(const SystemConfigState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(ApiConstants.systemConfig);
      final data = res.data['data'] as Map<String, dynamic>;
      state = SystemConfigState(
        multiCompany: data['multi_company_users'] == 'true',
        multiLocation: data['multi_location_users'] == 'true',
      );
    } catch (_) {
      state = const SystemConfigState();
    }
  }

  Future<bool> update(String key, bool value) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.put(ApiConstants.systemConfigKey(key), data: {'value': value.toString()});
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final systemConfigProvider = StateNotifierProvider<SystemConfigNotifier, SystemConfigState>(
  (ref) => SystemConfigNotifier(ref),
);
