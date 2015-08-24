library water;

import 'dart:html';
import 'dart:web_gl';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'dart:math';

import 'utils.dart' as utils;



class water{
  
  SendPort sendPort;
  int isoCounter = 0;
  ReceivePort receivePort = new ReceivePort();

  String workerUri;
  List map;
  
  //tells where we are located on the grid
  int locX;
  int locY;

  List vertices;
  List static;
  List fluid;
   
  var shader;
  Map<String, int> attributes;
  Map<String, int> uniforms;

  bool ready = false;
  
  RenderingContext gl;
  
  
  //Testing Stuff
  int startTime;
  int isolateStartTime;
  int isolateEndTime = 0;
  int endTime = 0;
  int updateCount = 0;

  
  water(RenderingContext gGl, List gHeighMap, int gLocX, int gLocY, int gState){
    //based on water state use a different isolate / method of simulating water

    
    map = gHeighMap;
    gl = gGl;
    locX = gLocX;
    locY = gLocY;
    
    workerUri = 'tracer.dart';//define what isolate to use
    //workerUri = 'water_isolate.dart';
    
    String vertex = """
        attribute vec3 aVertexPosition;
        attribute vec3 aVertexNormal;

        uniform mat4 uMVMatrix;
        uniform mat4 uPMatrix;

        varying vec3 pos;
        varying vec3 norm;

        void main(void) {
            gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);

            pos = vec3(uMVMatrix * vec4(aVertexPosition, 1.0));
            norm = aVertexNormal;
           
        
      }""";

        String fragment = """
          precision mediump float;

          varying vec3 pos;
          varying vec3 norm;
    
          uniform samplerCube skyMap;
      
          void main(void) {

              vec3 cameraPos = vec3(10.0,10.0,10.0);
              
              vec3 I = normalize(cameraPos - pos);
              vec3 R = reflect(I, normalize(norm));
              gl_FragColor = textureCube(skyMap, R);

        
      }""";
    
    shader = utils.loadShaderSource(gl, vertex, fragment);
    
    var attrib = ['aVertexPosition', 'aVertexNormal'];
    var unif = ['uMVMatrix', 'uPMatrix', 'uNormalMatrix'];
    
    attributes = utils.linkAttributes(gl, shader, attrib);
    uniforms = utils.linkUniforms(gl, shader, unif);
    
    traceR();
    //shallowWaterR();
    
  }
  
  
  shallowWaterR(){
    receivePort.listen((msg) {
      if (sendPort == null) {
        sendPort = msg;
      } else {
        if(msg[0] == "update"){
          endTime = new DateTime.now().millisecondsSinceEpoch;
          shallowWaterRV(msg);
        }else{
          isolateEndTime = msg[4];
          //endTime = new DateTime.now().millisecondsSinceEpoch;
          
          swSetup(msg);
        }
      }
    
    });

    isolateStartTime = new DateTime.now().millisecondsSinceEpoch;
    
    Isolate
        .spawnUri(Uri.parse(workerUri), [], receivePort.sendPort)
        .whenComplete(shallowWaterS);
  }
  
  shallowWaterUpdateS(){
    if(sendPort == null) {
      print("Not ready yet");
      new Future.delayed(const Duration(milliseconds: 15), shallowWaterUpdateS);
    } else {
      //print("requesting update");
      //startTime = new DateTime.now().millisecondsSinceEpoch;
      sendPort.send(["update"]); 
    }
  }
  
  
  shallowWaterS(){
    if(sendPort == null) {
      new Future.delayed(const Duration(milliseconds: 15), shallowWaterS);
    } else {
      
      sendPort.send(["init", map, map.length, locX, locY]); 
    }
  }
  
  shallowWaterRV(data){

    for(int i = 0; i < fluid.length; i++){
      gl.bindBuffer(ARRAY_BUFFER, fluid[i][1]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[1]), DYNAMIC_DRAW);
    }
    
    //print(endTime - startTime);

  }
  
  
  swSetup(data){
    fluid = new List(1);
       
    List fIndices = new List(data[1].length);
    List fVertices = new List(data[2].length);
    List fNormals = new List(data[3].length);
    
    for(int i = 0; i < fluid.length; i++){
      fluid[i] = new List(4);
      
      fIndices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, fIndices[i]);
      gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(data[1]), STATIC_DRAW);
      fluid[i][0] = fIndices[i];
      
      fVertices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fVertices[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[2]), DYNAMIC_DRAW);
      fluid[i][1] = fVertices[i];
      
      fNormals[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fNormals[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[3]), STATIC_DRAW);
      fluid[i][2] = fNormals[i];
      
      fluid[i][3] = data[1].length;   

    }

    ready = true;
  }
  
  traceS(){
    if(sendPort == null) {
      
      //print("Not ready yet");
      new Future.delayed(const Duration(milliseconds: 15), traceS);
    } else {
      //print("Sending Base Water Info");
      //isolateStartTime = new DateTime.now().millisecondsSinceEpoch;
      sendPort.send(["init", map, locX, locY]); 
    }
  }
  
  traceR(){
    receivePort.listen((msg) {
      if (sendPort == null) {
        sendPort = msg;
      } else {
        //print(msg);
        if(msg[0] == "update"){
          endTime = new DateTime.now().millisecondsSinceEpoch;
          //print(endTime - startTime);
          //timing.add(endTime - startTime);
          reloadVert(msg);
        }else{
          //print("DataR");
          isolateEndTime = new DateTime.now().millisecondsSinceEpoch;
          //print("$locY-----Time To Create Isolate: $isolateEndTime-------");
          //print(isolateEndTime);
          //print("$locY-----Time To Init------------$endTime--------------");
          //print(msg[2] - isolateStartTime);
          setup(msg);
        }
      }
    
    });
    
    
    Isolate
        .spawnUri(Uri.parse(workerUri), [], receivePort.sendPort)
        .whenComplete(traceS);
  }
  
  updateS(){
    if(sendPort == null) {
      print("Not ready yet");
      new Future.delayed(const Duration(milliseconds: 15), updateS);
    } else {
      //print("requesting update");
      startTime = new DateTime.now().millisecondsSinceEpoch;
      sendPort.send(["update"]); 
    }
  }
  

  
  setup(data){
    
    fluid = new List(data[0].length);
    static = new List(data[1].length);
    
    List sIndices = new List(data[1].length);
    List sVertices = new List(data[1].length);
    List sNormals = new List(data[1].length);
    
    for(int i = 0; i < static.length; i++){
      
      static[i] = new List(4);
      sIndices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, sIndices[i]);
      gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(data[1][i][0]), STATIC_DRAW);
      static[i][0] = sIndices[i];
      
      sVertices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, sVertices[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[1][i][1]), STATIC_DRAW);
      static[i][1] = sVertices[i];
      
      sNormals[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, sNormals[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[1][i][2]), STATIC_DRAW);
      static[i][2] = sNormals[i];
      
      static[i][3] = data[1][i][0].length;

    }   
    
    List fIndices = new List(data[0].length);
    List fVertices = new List(data[0].length);
    List fNormals = new List(data[0].length);
    vertices = new List(data[0].length);
    
    for(int i = 0; i < fluid.length; i++){
      fluid[i] = new List(4);
      
      fIndices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, fIndices[i]);
      gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(data[0][i][0]), STATIC_DRAW);
      fluid[i][0] = fIndices[i];
      
      fVertices[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fVertices[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[0][i][1]), DYNAMIC_DRAW);
      fluid[i][1] = fVertices[i];
      
      fNormals[i] = gl.createBuffer();
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, fNormals[i]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[0][i][2]), STATIC_DRAW);
      fluid[i][2] = fNormals[i];
      
      fluid[i][3] = data[0][i][0].length;   

    }

    ready = true;
    //print("gotten this far");
  }
  
  reloadVert(data){
    
    for(int i = 0; i < fluid.length; i++){
      gl.bindBuffer(ARRAY_BUFFER, fluid[i][1]);
      gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(data[1][i]), DYNAMIC_DRAW);
      //print(data[1][i]);
    }
    //print(endTime - startTime);
    /*
    if(timing.length == 100){
      int avg = 0;
      for(int i = 0; i < 100; i++){
        avg = avg + timing[i];
      }
      avg = avg ~/100;
      timing = new List();
      print("$locY:::::::::update timing::::::::$avg");
    }*/

    //print("------------------------------------------------------------------------------");
  }

  //do the update on the main core, so dont need to pass more data, updates are easy
  update(){
    if(ready){//make sure the data is loaded before trying anything
      //for every fluid body of water, update teh vertices
      updateS();     
    }
  }
  
  draw(Matrix4 viewMat, Matrix4 projectMat) {

    if(ready){
      gl.useProgram(shader);
      
      //gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);

      utils.setMatrixUniforms(gl, viewMat, projectMat, uniforms['uPMatrix'], uniforms['uMVMatrix'], uniforms['uNormalMatrix']);
      gl.enableVertexAttribArray(attributes['aVertexPosition']);
      gl.enableVertexAttribArray(attributes['aVertexNormal']);
      
      //render static objects first
      for(int i = 0; i < static.length; i++){
        gl.bindBuffer(ARRAY_BUFFER, static[i][1]);
        gl.vertexAttribPointer(attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);
        
        gl.bindBuffer(ARRAY_BUFFER, static[i][2]);
        gl.vertexAttribPointer(attributes['aVertexNormal'], 3, FLOAT, false, 0, 0);
        
        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, static[i][0]);
        gl.drawElements(TRIANGLES, static[i][3], UNSIGNED_SHORT, 0);
      }
      //render dynamic objects
      for(int i = 0; i < fluid.length; i++){
        gl.bindBuffer(ARRAY_BUFFER, fluid[i][1]);
        gl.vertexAttribPointer(attributes['aVertexPosition'], 3, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, fluid[i][2]);
        gl.vertexAttribPointer(attributes['aVertexNormal'], 3, FLOAT, false, 0, 0);
        
        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, fluid[i][0]);
        gl.drawElements(TRIANGLES, fluid[i][3], UNSIGNED_SHORT, 0);
      }
    }    
  }
  
}

















