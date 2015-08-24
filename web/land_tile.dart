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
  
  //////for timing
  int startTime;
  int isolateStartTime;
  int isolateEndTime;
  int genTime;

  ////////////////
  
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
    
    

    
    //print(heightMap.length);
  }
  
  dataSend(){
    if(sendPort == null) {
      //print("Not ready yet");
      new Future.delayed(const Duration(milliseconds: 15), dataSend);
    } else {
      //print("Sending");
      //startTime = new DateTime.now().millisecondsSinceEpoch;
      isolateStartTime = new DateTime.now().millisecondsSinceEpoch;
      sendPort.send(["init", res, locX, locY]); 
    }
  }
  
  dataRec(){
    receivePort.listen((msg) {
      if (sendPort == null) {
        sendPort = msg;
      } else {
        //print("Reveiving");
        switch(msg[0]){
          case "init":         
            isolateEndTime = msg[4];
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
  //topEdge,botEdge,iPlusOne,iMinusOne
  makeEdges(List topEdge, List botEdge, List iPlusOne, List iMinusOne){
    //add vertices for minX edge
    

    List ind = new List<int>();
    List vert = new List();
    
    int m = 1;
    if(res == 33){
      m = 4;
    }else if(res == 65){
      m = 2;
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
          
          for(int i = 0; i < res; i++){
            vert.add((i.toDouble() * m) + (128 * locX));
            vert.add(heightMap[i][1]);
            vert.add((128 / (res - 1)) + (128 * locY));
          }

          for(int i = 0; i < 65; i++){
            vert.add((i.toDouble() * 2.0) + (128 * locX));
            if(iPlusOne == null){
              vert.add(10.0);
            }else{
              vert.add(iPlusOne[i]);
            }
            vert.add((128 / (res - 1)) + (128 * locY)-m);
          }

          if(res == 129){
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
          }else if(res == 65){
            for(int i = 0; i < res-1; i ++){
              ind.add(i);
              ind.add(i+1);
              ind.add(res+i);
              
              ind.add(res+i);
              ind.add(i+1);
              ind.add(res+i+1);

            }
          }else if(res == 33){
            for(int i = 0; i < res - 1; i++){
              ind.add(i);
              ind.add(res + (i*2));
              ind.add(res + (i*2)+1);
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + (i*2)+1);
              
              ind.add(i+1);
              ind.add(res + (i*2)+2);
              ind.add(res + (i*2)+1);
            }
          }

                
          break;
        case 1:
          //minY
          
          double multi =  ((res-1) / 64);
          
          for(int i = 0; i < res; i++){
            vert.add(128.0 * locX + (m*1));
            vert.add(heightMap[1][i]);
            vert.add(i.toDouble() * m + (128.0 * locY));
          }
          for(int i = 0; i < 65; i++){
            vert.add((128.0 * locX));
            if(botEdge == null){
              vert.add(10.0);
            }else{
              vert.add(botEdge[i]);
            }            
            vert.add(i.toDouble() * 2.0 + (128.0 * locY));
          }
          
          if(res == 129){
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
          }else if(res == 65){
            for(int i = 0; i < res-1; i ++){
              ind.add(i);
              ind.add(i+1);
              ind.add(res+i);
              
              ind.add(res+i);
              ind.add(i+1);
              ind.add(res+i+1);

            }
          }else if(res == 33){
            for(int i = 0; i < res - 1; i++){
              ind.add(i);
              ind.add(res + (i*2));
              ind.add(res + (i*2)+1);
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + (i*2)+1);
              
              ind.add(i+1);
              ind.add(res + (i*2)+2);
              ind.add(res + (i*2)+1);
            }
          }
          
          break;
        case 2:
          
          double multi =  ((res-1) / 64);
          
          for(int i = 0; i < res; i++){
            vert.add((i.toDouble() * m) + (128 * locX));
            vert.add(heightMap[i][res-2]);
            vert.add((128 / (65 - 1)) + (128 * locY) + 126-m);
          }

          for(int i = 0; i < 65; i++){
            vert.add((i.toDouble() * 2.0) + (128 * locX));
            if(iMinusOne == null){
              vert.add(10.0);
            }else{
              vert.add(iMinusOne[i]);
            }
            vert.add((128 / (65 - 1)) + (128 * locY) +126);
          }
          
          if(res == 129){
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
          }else if(res == 65){
            for(int i = 0; i < res-1; i ++){
              ind.add(i);
              ind.add(i+1);
              ind.add(res+i);
              
              ind.add(res+i);
              ind.add(i+1);
              ind.add(res+i+1);

            }
          }else if(res == 33){
            for(int i = 0; i < res - 1; i++){
              ind.add(i);
              ind.add(res + (i*2));
              ind.add(res + (i*2)+1);
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + (i*2)+1);
              
              ind.add(i+1);
              ind.add(res + (i*2)+2);
              ind.add(res + (i*2)+1);
            }
          }
                  
          break;
        case 3://maxY
          
          double multi =  ((res-1) / 64);
          
          for(int i = 0; i < res; i++){
            vert.add((128 / (65 - 1)) + (128 * locX) + 126-m);
            vert.add(heightMap[res-2][i]);
            vert.add(i.toDouble() * m + (128.0 * locY));
          }
          
          for(int i = 0; i < 65; i++){
            vert.add((128 / (65 - 1)) + (128 * locX) + 126);
            if(topEdge == null){
              vert.add(10.0);
            }else{
              vert.add(topEdge[i]);
            }
            vert.add(i.toDouble() * 2 + (128.0 * locY));
          }
          if(res == 129){
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
          }else if(res == 65){
            for(int i = 0; i < res-1; i ++){
              ind.add(i);
              ind.add(i+1);
              ind.add(res+i);
              
              ind.add(res+i);
              ind.add(i+1);
              ind.add(res+i+1);

            }
          }else if(res == 33){
            for(int i = 0; i < res - 1; i++){
              ind.add(i);
              ind.add(res + (i*2));
              ind.add(res + (i*2)+1);
              
              ind.add(i);
              ind.add(i+1);
              ind.add(res + (i*2)+1);
              
              ind.add(i+1);
              ind.add(res + (i*2)+2);
              ind.add(res + (i*2)+1);
            }
          }
          
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



















