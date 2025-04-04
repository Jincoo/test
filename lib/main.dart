import 'dart:io';
import 'package:flutter/material.dart';
import 'package:exif/exif.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '사진 정보 추출',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: PhotoInfoExtractor(),
    );
  }
}

class PhotoInfoExtractor extends StatefulWidget {
  @override
  _PhotoInfoExtractorState createState() => _PhotoInfoExtractorState();
}

class _PhotoInfoExtractorState extends State<PhotoInfoExtractor> {
  File? _imageFile;
  String? _dateTime;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.accessMediaLocation.request();
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _dateTime = null;
          _latitude = null;
          _longitude = null;
        });
        
        await _extractExifData();
      }
    } catch (e) {
      print('파일 선택 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _extractExifData() async {
    if (_imageFile == null) return;
    
    try {
      // EXIF 데이터 읽기
      final tags = await readExifFromFile(_imageFile!);
      
      // 촬영 시간 추출
      if (tags.containsKey('EXIF DateTimeOriginal')) {
        String originalDateTime = tags['EXIF DateTimeOriginal']!.printable;
        
        // EXIF 날짜 형식(예: 2025:04:02 15:50:35)을 사용자 친화적 형식으로 변환
        try {
          final exifDateFormat = DateFormat('yyyy:MM:dd HH:mm:ss');
          final date = exifDateFormat.parse(originalDateTime);
          final userDateFormat = DateFormat('yyyy년 MM월 dd일 HH시 mm분 ss초');
          
          setState(() {
            _dateTime = userDateFormat.format(date);
          });
        } catch (e) {
          print('날짜 변환 오류: $e');
          setState(() {
            _dateTime = originalDateTime; // 변환 실패 시 원본 문자열 사용
          });
        }
      }
      
      // GPS 정보 추출
      _extractGpsCoordinates(tags);
    } catch (e) {
      print('EXIF 데이터 읽기 오류: $e');
    }
  }

  void _extractGpsCoordinates(Map<String, IfdTag> tags) {
    try {      
      // 위도 정보 추출
      if (tags.containsKey('GPS GPSLatitude') && tags.containsKey('GPS GPSLatitudeRef')) {
        final latitudeRef = tags['GPS GPSLatitudeRef']!.printable;
        final latitudeTag = tags['GPS GPSLatitude']!;
        
        double? latitude = _parseCoordinate(latitudeTag, latitudeRef == 'S');
        
        if (latitude != null) {
          setState(() {
            _latitude = latitude;
          });
        }
      }
      
      // 경도 정보 추출
      if (tags.containsKey('GPS GPSLongitude') && tags.containsKey('GPS GPSLongitudeRef')) {
        final longitudeRef = tags['GPS GPSLongitudeRef']!.printable;
        final longitudeTag = tags['GPS GPSLongitude']!;
        
        double? longitude = _parseCoordinate(longitudeTag, longitudeRef == 'W');
        
        if (longitude != null) {
          setState(() {
            _longitude = longitude;
          });
        }
      }
    } catch (e) {
      print('GPS 좌표 추출 오류: $e');
    }
  }
  
  // 좌표 파싱 함수
  double? _parseCoordinate(IfdTag tag, bool isNegative) {
    try {
      String valuesString = tag.values.toString();
      
      // 대괄호와 공백 제거
      valuesString = valuesString.replaceAll('[', '').replaceAll(']', '').trim();
      
      // 콤마로 분리
      List<String> parts = valuesString.split(',');
      List<double> parsedValues = [];
      
      for (String part in parts) {
        part = part.trim();
        if (part.contains('/')) {
          // 분수 형식 처리 (예: 229443/12500)
          List<String> fraction = part.split('/');
          if (fraction.length == 2) {
            double numerator = double.parse(fraction[0]);
            double denominator = double.parse(fraction[1]);
            if (denominator != 0) {
              parsedValues.add(numerator / denominator);
            }
          }
        } else {
          // 정수 또는 소수점 형식 처리 (예: 37, 28)
          double? value = double.tryParse(part);
          if (value != null) {
            parsedValues.add(value);
          }
        }
      }
      
      if (parsedValues.length >= 3) {
        double result = parsedValues[0] + (parsedValues[1] / 60) + (parsedValues[2] / 3600);
        return isNegative ? -result : result;
      }
    } catch (e) {
      print('좌표 파싱 오류: $e');
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('사진 정보 추출'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_imageFile != null)
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: FileImage(_imageFile!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              SizedBox(height: 24),
              if (_isLoading)
                CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.photo_library),
                  label: Text('사진 선택하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: Size(200, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              SizedBox(height: 24),
              
              if (_imageFile != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '사진 정보',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800
                          ),
                        ),
                        Divider(),
                        _buildInfoRow('촬영 시간:', _dateTime ?? '정보 없음'),
                        SizedBox(height: 8),
                        _buildInfoRow('위도:', _latitude != null ? '${_latitude!.toStringAsFixed(6)}' : '정보 없음'),
                        SizedBox(height: 8),
                        _buildInfoRow('경도:', _longitude != null ? '${_longitude!.toStringAsFixed(6)}' : '정보 없음'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}