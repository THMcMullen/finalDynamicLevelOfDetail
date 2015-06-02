library land_tile;

import 'dart:html';
import 'dart:web_gl';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';

import 'utils.dart' as utils;



class land_tile{
  SendPort sendPort;
  ReceivePort receivePort = new ReceivePort(); 
  String workerUri;
  
  //tells where we are located on the grid
  int locX;
  int locY;
  //resolution this tile should be
  int res;
  
  RenderingContext gl;
  Program shader;
  Texture skyBox;
  
  //Allows for a cleaner linking of attributes and uniforms
  Map<String, int> attribute;
  Map<String, int> uniforms;
  
  //vertex shader and fragment shader
  String vertex;
  String fragment;
  
  var attrib;
  var unif;
  
  var indices;
  var vertices;
  int numberOfTri;
  
  //store the height map
  List heightMap;
  bool ready = false;
  
  //when the class is constructed do nothing for the start
  land_tile(){
    //file containing all the infomation needed to proccess and adapt a land tile
    workerUri = 'land_isolate.dart';
    
  }
  
  //data[1] = heightMap
  //data[2] = indices
  //data[3] = vertices
  setData(data){
    //create the inside buffers for each tile, using data from the isolate
    heightMap = data[1];
    indices = gl.createBuffer();
    vertices = gl.createBuffer();
    
    gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, indices);
    gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(data[2]), STATIC_DRAW);
    
    gl.bindBuffer(RenderingContext.ARRAY_BUFFER, vertices);
    gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(data[3]), STATIC_DRAW);
    numberOfTri = data[2].length;
    ready = true;
  }
  
  dataSend(){
    if(sendPort == null) {
      print("Not ready yet");
      new Future.delayed(const Duration(milliseconds: 15), dataSend);
    } else {
      print("Sending");
      sendPort.send(["init", res, locX, locY]); 
    }
  }
  
  dataRec(){
    receivePort.listen((msg) {
      if (sendPort == null) {
        sendPort = msg;
      } else {
        print("Reveiving");
        switch(msg[0]){
          case "init":
            setData(msg);
        }
      }
    });
    
    Isolate
           .spawnUri(Uri.parse(workerUri), [], receivePort.sendPort)
           .whenComplete(dataSend);
  }
  
  
  initLand(RenderingContext gGl, int gRes, int gLocX, int gLocY){
    gl = gGl;
    res = gRes;
    locX = gLocX;
    locY = gLocY;
    
    //shaders to color the landscape based on height
    String vertex = """
        attribute vec3 aVertexPosition;
        attribute vec3 aVertexNormal;

        uniform mat4 uMVMatrix;
        uniform mat4 uPMatrix;
        
        varying vec4 pos;

        void main(void) {
            gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
          
            pos = vec4(aVertexPosition,1.0);
           
        
      }""";

    String fragment = """
          precision mediump float;

          varying vec4 pos;

          void main(void) {

              vec4 color = pos;
              float alpha = color.y / 5.0;

              if(color.y < 5.0)
                color = vec4(0.0, 0.0,1.0, 1.0);
              else
                color = vec4(0.0, 1.0, 0.0, 1.0);
              
          
              gl_FragColor = color;
              
        
      }""";

    //creates the shaders unique for the landscape
    shader = utils.loadShaderSource(gl, vertex, fragment);
  
    attrib = ['aVertexPosition', 'aVertexNormal'];
    unif = ['uMVMatrix', 'uPMatrix'];
  
    attribute = utils.linkAttributes(gl, shader, attrib);
    uniforms = utils.linkUniforms(gl, shader, unif);
    dataRec();
  }
    
  draw(Matrix4 viewMat, Matrix4 projectMat) {

      if(ready){
        gl.useProgram(shader);
  
        utils.setMatrixUniforms(gl, viewMat, projectMat, uniforms['uPMatrix'], uniforms['uMVMatrix'], uniforms['uNormalMatrix']);
  
        gl.enableVertexAttribArray(attribute['aVertexPosition']);
        gl.bindBuffer(ARRAY_BUFFER, vertices);
        gl.vertexAttribPointer(attribute['aVertexPosition'], 3, FLOAT, false, 0, 0);
  
        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, indices);
        gl.drawElements(TRIANGLES, numberOfTri, UNSIGNED_SHORT, 0);
      }
    }
}
