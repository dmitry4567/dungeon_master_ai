import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class TTSApi {
  final Dio _dio;

  TTSApi(this._dio);

  Stream<List<int>> streamTTS(String text, String messageId) {
    final response = _dio.post<ResponseBody>(
      '/tts/stream',
      data: {
        'text': text,
        'message_id': messageId,
      },
      options: Options(
        responseType: ResponseType.stream,
      ),
    );

    return response.asStream().asyncExpand((r) => r.data!.stream);
  }

  Future<bool> isTtsAvailable() async {
    try {
      final response = await _dio.get('/tts/status');
      return response.data['available'] as bool;
    } catch (e) {
      return false;
    }
  }
}
