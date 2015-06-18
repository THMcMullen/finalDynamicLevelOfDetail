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
  
  List edgeIndices;
  List edgeVertices;
  List edgeNumberOfTri;
  
  //store the height map
  List heightMap;
  bool ready = false;
  bool edgeReady = false;
  
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
    
    print(heightMap.length);
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
              float alpha = color.y / 10.0;

              if(color.y < 5.0)
                color = vec4(0.688, 0.875, 0.898, alpha + 0.5);
              else if(color.y < 7.0)
                color = vec4(0.887, 0.739, 0.557, alpha + 0.2);
              else if(color.y < 10.5)
                color = vec4(0.420, 0.557, 0.137, alpha - 0.1);
              else
                color = vec4(0.439, 0.502, 0.565, 1.0/alpha - 0.3);
              
          
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
  
  makeEdges(List minX, List maxX, List minY, List maxY){
    //add vertices for minX edge
    

    List ind = new List<int>();
    List vert = new List();

    print("minX: $minX");
    print("maxX: $maxX");
    
    int m = 1;
    if(res == 33){
      m = 4;
    }else if(res == 65){
      m = 2;
      print("m");
    }
    
    edgeNumberOfTri = new List(4);
    edgeIndices = new List(4);
    edgeVertices = new List(4);
    for(int h =0; h < 4; h ++){
      edgeIndices[h] = gl.createBuffer();
      edgeVertices[h] = gl.createBuffer();
      
      //reset the list
      ind = new List();
      vert = new List();
      switch (h){
        case 0: // edge for x at start

          double multi =  ((res-1) / 64);
          
          int r = 0;
          if(res == 129){
            r = 1;
          }
          
          for(int i = 0; i < res; i++){
            vert.add(i.toDouble() * m);
            vert.add(heightMap[i][1]);
            vert.add((128 / (65 - 1)) + (128 * locY)-r);
          }

          for(int i = 0; i < 65; i++){
            vert.add(i.toDouble() * 2.0);
            if(minX == null){
              vert.add(10.0);
            }else{
              vert.add(minX[i]);
            }
            vert.add((128 / (65 - 1)) + (128 * locY)-2);
          }

          
          for(int i = 0; i < res-1; i +=2){
            ind.add(i);
            ind.add(i+1);
            ind.add((res + (i / multi)).toInt());
            
            ind.add(i+1);
            ind.add(i+2);
            ind.add(((res + ((i+2) / multi)).toInt()));
            
            ind.add(i+1);
            ind.add((res + (i / multi)).toInt());
            ind.add(((res + ((i+2) / multi)).toInt()));
          }
          
          /*ind.add(1);
          ind.add(res);
          ind.add(res+1);
          ind.add(1);
          ind.add(2);
          ind.add(res+1);
          
          
          ind.add(res-3);
          ind.add(res-2);
          ind.add(res+63);
          ind.add(res-2);
          ind.add(res+63);
          ind.add(res+64);*/

      
          break;
        case 1:
          
          for(int i = 0; i < 2 ; i++){
            for(int j = 0; j < res; j++){
              vert.add(i * (128 / (res - 1)) + (128 * locX));
              if(i == 1){
                vert.add(heightMap[i][j]);
              }else{
                vert.add(10.0);
              }
              vert.add(j * (128 / (res - 1)) + (128 * locY));
            }
          }
         /* for(int i = 1; i < res-2 ; i++){
            for(int j = 0; j < 1 ; j++){
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + i);
              ind.add(i+1);
              ind.add(res+i);
              ind.add(res+i+1);
            }
          } */
          
          ind.add(0);
          ind.add(0);
          ind.add(0);
          
          break;
        case 2:
          
          for(int i = 0; i < res; i++){
            vert.add(i.toDouble() * m);
            vert.add(heightMap[i][res-2]);
            vert.add((128 / (65 - 1)) + (128 * locY) + 125);
          }

          for(int i = 0; i < 65; i++){
            vert.add(i.toDouble() * 2.0);
            if(maxX == null){
              vert.add(10.0);
            }else{
              vert.add(maxX[i]);
            }
            vert.add((128 / (65 - 1)) + (128 * locY) +126);
          }
          
          double multi =  ((res-1) / 64);
          for(int i = 0; i < res-1; i +=2){
            ind.add(i);
            ind.add(i+1);
            ind.add((res + (i / multi)).toInt());
            
            ind.add(i+1);
            ind.add(i+2);
            ind.add(((res + ((i+2) / multi)).toInt()));
            
            ind.add(i+1);
            ind.add((res + (i / multi)).toInt());
            ind.add(((res + ((i+2) / multi)).toInt()));
          }
 
          
          break;
        case 3:
          
          for(int i = res-2; i < res ; i++){
            for(int j = 0; j < res; j++){
              vert.add(i * (128 / (res - 1)) + (128 * locX));
              if(i == res-1){
                vert.add(10.0);
              }else{
                vert.add(10.0);//heightMap[i][j]);
              }
              vert.add(j * (128 / (res - 1)) + (128 * locY));
            }
          }

          /*for(int i = 1; i < res-2 ; i++){
            for(int j = 0; j < 2 ; j++){
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + i);
              ind.add(i+1);
              ind.add(res+i);
              ind.add(res+i+1);
            }
          } 
          break;*/
          
          ind.add(0);
          ind.add(0);
          ind.add(0);
          
          
      }
      
      edgeNumberOfTri[h] = ind.length;
      
      gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, edgeIndices[h]);
      gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(ind), STATIC_DRAW);
     
      gl.bindBuffer(RenderingContext.ARRAY_BUFFER, edgeVertices[h]);
      gl.bufferDataTyped(ARRAY_BUFFER, new Float32List.fromList(vert), STATIC_DRAW);
    }
        
        
        ind.length;
    //edgeIndices = gl.createBuffer();
    //edgeVertices = gl.createBuffer();

    
    
    edgeReady = true;
    
    
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
      
      if(edgeReady){
        
        for(int i = 0; i < 4 ; i++){
          gl.bindBuffer(ARRAY_BUFFER, edgeVertices[i]);
          gl.vertexAttribPointer(attribute['aVertexPosition'], 3, FLOAT, false, 0, 0);  
          
          gl.bindBuffer(ELEMENT_ARRAY_BUFFER, edgeIndices[i]);
          gl.drawElements(TRIANGLES, edgeNumberOfTri[i], UNSIGNED_SHORT, 0);
        }
      }
    }
  }
}



















