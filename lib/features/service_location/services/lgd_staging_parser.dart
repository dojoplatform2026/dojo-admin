import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Local-only LGD staging parser; no Firebase dependency or write path.
class LgdStageRecord {
 final String level,code,english,file; final String? local,parentLevel,parentCode; final int rowNumber; final Map<String,String> raw; final Map<String,String?> extra;
 const LgdStageRecord({required this.level,required this.code,required this.english,required this.local,required this.parentLevel,required this.parentCode,required this.file,required this.rowNumber,required this.raw,required this.extra});
 String get identity=>'LGD|'+level+'|'+code;
 Map<String,Object?> toJson()=>{'schemaVersion':1,'sourceSystem':'LGD','sourceLevel':level,'sourceCode':code,'sourceNameEnglish':english,'sourceNameLocal':local,'parentSourceLevel':parentLevel,'parentSourceCode':parentCode,'sourceUpdatedAt':null,'sourceFile':file,'sourceRowNumber':rowNumber,'rawSourceFields':raw,'additionalFields':extra};
}
class LgdStageFile {
 final String file,hash; final int bytes,rows; final List<String> headers;
 const LgdStageFile(this.file,this.hash,this.bytes,this.rows,this.headers);
 Map<String,Object?> toJson()=>{'sourceFile':file,'sha256':hash,'byteSize':bytes,'parsedRows':rows,'headers':headers};
}
class LgdStageResult {
 final List<LgdStageRecord> records; final List<LgdStageFile> files; final List<String> errors,warnings;
 const LgdStageResult(this.records,this.files,this.errors,this.warnings);
 bool get isValid=>errors.isEmpty&&records.isNotEmpty;
 String? get jsonLines=>isValid?records.map((r)=>jsonEncode(r.toJson())).join('\n')+'\n':null;
 String get outputSha256=>jsonLines==null?'':sha256.convert(utf8.encode(jsonLines!)).toString();
 Map<String,Object?> reportJson()=>{'schemaVersion':1,'valid':isValid,'errors':errors,'warnings':warnings,'files':files.map((f)=>f.toJson()).toList(),'recordCount':records.length,'outputSha256':outputSha256.isEmpty?null:outputSha256};
}
class LgdStagingParser {
 static const paths={'states':'review/lgd_exports/states.csv','districts':'review/lgd_exports/districts.csv','sub_districts':'review/lgd_exports/sub_districts.csv'};
 String n(String s)=>s.replaceFirst('\uFEFF','').trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'),'');
 LgdStageResult parse({required String statesCsv,required String districtsCsv,required String subDistrictsCsv}) {
  final errors=<String>[],warnings=<String>[],records=<LgdStageRecord>[],files=<LgdStageFile>[];
  final inputs={'states':statesCsv,'districts':districtsCsv,'sub_districts':subDistrictsCsv};
  for(final input in inputs.entries) {
   final path=paths[input.key]!,bytes=utf8.encode(input.value),csv=parseCsv(input.value);
   if(csv.error!=null){errors.add(path+': '+csv.error!);files.add(LgdStageFile(path,sha256.convert(bytes).toString(),bytes.length,0,const[]));continue;}
   if(csv.rows.isEmpty){errors.add(path+': missing header.');continue;}
   final headers=csv.rows.first.map((x)=>x.trim()).toList(),nh=csv.rows.first.map(n).toList();
   if(nh.any((x)=>x.isEmpty))errors.add(path+': empty header.');
   if(nh.toSet().length!=nh.length)errors.add(path+': duplicate headers.');
   final rows=<Map<String,String>>[];
   for(var i=1;i<csv.rows.length;i++){final cells=csv.rows[i];if(cells.length==1&&cells.first.trim().isEmpty)continue;if(cells.length!=headers.length){errors.add(path+' row '+(i+1).toString()+': expected '+headers.length.toString()+' fields, found '+cells.length.toString()+'.');continue;}rows.add({for(var j=0;j<headers.length;j++)headers[j]:cells[j]});}
   files.add(LgdStageFile(path,sha256.convert(bytes).toString(),bytes.length,rows.length,headers));
   if(nh.any((x)=>x.isEmpty)||nh.toSet().length!=nh.length)continue;
   for(var i=0;i<rows.length;i++){
    final raw=rows[i],v={for(final e in raw.entries)n(e.key):e.value};
    String? get(List<String> aliases){for(final a in aliases){final x=v[n(a)];if(x!=null)return x.trim();}return null;}
    final level=switch(input.key){'states'=>'state','districts'=>'district',_=>'sub_district'};
    final code=get(switch(level){'state'=>['State Code'],'district'=>['district_code'],_=>['sub_district_code','subdistrict_code','sub_district_lgd_code','subdistrict_lgd_code']});
    final en=get(switch(level){'state'=>['State Name (In English)'],'district'=>['district_name_english'],_=>['sub_district_name_english','subdistrict_name_english','sub_district_name_in_english','subdistrict_name_in_english']});
    final local=get(switch(level){'state'=>['State Name (In Local)'],'district'=>['district_name_local'],_=>['sub_district_name_local','subdistrict_name_local','sub_district_name_in_local','subdistrict_name_in_local']});
    final state=get(['state_code','State Code']),district=get(['district_code']),row=i+2;
    if(code==null||code.isEmpty){errors.add(path+' row '+row.toString()+': source code missing or header unsupported.');continue;}
    if(en==null||en.isEmpty){errors.add(path+' row '+row.toString()+': English name missing.');continue;}
    final pl=level=='district'?'state':level=='sub_district'?'district':null,pc=level=='district'?state:level=='sub_district'?district:null;
    if(pl!=null&&(pc==null||pc.isEmpty)){errors.add(path+' row '+row.toString()+': parent code missing.');continue;}
    if(local==null||local.isEmpty)warnings.add(path+' row '+row.toString()+': local-language name missing.');
    final extra=<String,String?>{};
    for(final a in ['State Version','Census 2001 Code','Census 2011 Code','State or UT','state_census2011_code','district_census2011_code','sub_district_census2011_code','subdistrict_census2011_code']){final x=get([a]);if(x!=null)extra[n(a)]=x;}
    if(level=='sub_district'&&state!=null)extra['state_code']=state;
    records.add(LgdStageRecord(level:level,code:code,english:en,local:local==null||local.isEmpty?null:local,parentLevel:pl,parentCode:pc,file:path,rowNumber:row,raw:Map.of(raw),extra:extra));
   }
  }
  final seen=<String>{},states=records.where((r)=>r.level=='state').map((r)=>r.code).toSet(),districts=<String,LgdStageRecord>{};
  for(final r in records){if(!seen.add(r.identity))errors.add('Duplicate source identity: '+r.identity+'.');if(r.level=='district'){districts.putIfAbsent(r.code,()=>r);if(!states.contains(r.parentCode))errors.add(r.file+' row '+r.rowNumber.toString()+': state parent '+(r.parentCode??'null')+' does not exist.');}}
  for(final r in records.where((r)=>r.level=='sub_district')){final p=districts[r.parentCode];if(p==null){errors.add(r.file+' row '+r.rowNumber.toString()+': district parent '+(r.parentCode??'null')+' does not exist.');continue;}final s=r.extra['state_code'];if(s!=null&&s.isNotEmpty&&s!=p.parentCode)errors.add(r.file+' row '+r.rowNumber.toString()+': state code '+s+' does not match district parent state '+(p.parentCode??'null')+'.');}
  return LgdStageResult(errors.isEmpty?records:const[],files,errors,warnings);
 }
 _Csv parseCsv(String input){
  final s=input.replaceFirst('\uFEFF','');if(s.trim().isEmpty)return const _Csv([],'CSV is empty.');
  final rows=<List<String>>[];var row=<String>[];final field=StringBuffer();var quoted=false,after=false,rec=1;
  void endField(){row.add(field.toString());field.clear();after=false;} void endRow(){endField();rows.add(row);row=<String>[];rec++;}
  for(var i=0;i<s.length;i++){final c=s[i];if(quoted){if(c=='"'){if(i+1<s.length&&s[i+1]=='"'){field.write('"');i++;}else{quoted=false;after=true;}}else{field.write(c);}continue;}
   if(after&&c!=','&&c!='\n'&&c!='\r'&&c.trim().isNotEmpty)return _Csv([],'malformed CSV near record '+rec.toString()+': text after quote.');
   if(c=='"'&&field.isEmpty&&!after)quoted=true;else if(c=='"')return _Csv([],'malformed CSV near record '+rec.toString()+': quote in unquoted field.');
   else if(c==',')endField();else if(c=='\n'||c=='\r'){if(c=='\r'&&i+1<s.length&&s[i+1]=='\n')i++;endRow();}else field.write(c);
  }
  if(quoted)return const _Csv([],'malformed CSV: unclosed quote.');if(field.isNotEmpty||row.isNotEmpty)endRow();return _Csv(rows,null);
 }
}
class _Csv{final List<List<String>> rows;final String? error;const _Csv(this.rows,this.error);}
