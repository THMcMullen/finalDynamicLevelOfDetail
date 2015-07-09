library core;

import 'dart:html';
import 'dart:web_gl';
import 'dart:async';

import 'package:vector_math/vector_math.dart';

import 'camera.dart' as cam;
import 'land_tile.dart';
import 'water.dart';

class core {

  //base variables to use for webgl
  RenderingContext gl;
  CanvasElement canvas;
  //camera infomation
  cam.camera camera;
  Matrix4 projectionMat;
  //texture infomation
  List images;
  Texture skyBox;

  //for testing
  land_tile baseLand;
  water baseWater;
  land_tile secondLand;
  water secondWater;
  
  water three;
  water four;

  List landContainer;
  List waterContainer;
  
  
  //////for timing
  DateTime startTime;
  int genTime;
  
  bool check = false; 
  int testSize = 64;
  List avg;
  ////////////////

  //what all tiles base the size on
  int baseSystemSize = 129;

  core(RenderingContext gGl, CanvasElement gCanvas) {
    gl = gGl;
    canvas = gCanvas;
    print("hello");
    
    avg = new List<int>(testSize);
    
    //setup camera and projection matrix
    camera = new cam.camera(canvas);
    projectionMat =
        makePerspectiveMatrix(45, (canvas.width / canvas.height), 1, 10000);
    setPerspectiveMatrix(
        projectionMat, 45, (canvas.width / canvas.height), 1.0, 10000.0);

    gl.clearColor(1.0, 1.0, 1.0, 1.0);
    gl.clearDepth(1.0);
    gl.enable(RenderingContext.DEPTH_TEST);

    //load in skybox
    load();
  }
  //loads in the imagesused for creating the skybox texture
  loadTextures() {
    skyBox = gl.createTexture();
    gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);
    for (int i = 0; i < images.length; i++) {
      gl.texImage2D(TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, RGB, RGB, UNSIGNED_BYTE,
          images[i]);
    }

    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_MAG_FILTER, LINEAR);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_MIN_FILTER, LINEAR);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_WRAP_T, CLAMP_TO_EDGE);
  }

  void load() {
    ImageElement right = new ImageElement(src: "images/right.jpg");
    ImageElement left = new ImageElement(src: "images/left.jpg");
    ImageElement top = new ImageElement(src: "images/top.jpg");
    ImageElement bottom = new ImageElement(src: "images/bottom.jpg");
    ImageElement back = new ImageElement(src: "images/back.jpg");
    ImageElement front = new ImageElement(src: "images/front.jpg");
    images = [left, right, top, bottom, front, back];

    var futures = [
      right.onLoad.first,
      left.onLoad.first,
      top.onLoad.first,
      bottom.onLoad.first,
      back.onLoad.first,
      front.onLoad.first
    ];

    Future.wait(futures).then((_) => loadTextures());
  }

  initWater() {
    for(int i = 0; i < testSize; i++){
      if(landContainer[0][i].heightMap == null){
        check = false;
      }
    }
    if(check == false){
      check = true;
      new Future.delayed(const Duration(milliseconds: 15), initWater);
    } else {
      for(int i = 0; i < testSize; i++){        
        waterContainer[0][i] = new water(gl, landContainer[0][i].heightMap, 0, i, 1);
      }
      waterTiming();
    }
  }
  
  bool waterCheck = false;
  int minTime;
  int maxTime;
  
  waterTiming(){
    for(int i = 0; i < testSize; i++){
      if(waterContainer[0][i].isolateEndTime == 0){
        waterCheck = false;
      }
    }
    if(waterCheck == false){
      waterCheck = true;
      new Future.delayed(const Duration(milliseconds: 15), waterTiming);
    } else {
      for(int i = 0; i < testSize; i++){        
        if(i == 0){
          minTime = waterContainer[0][i].isolateStartTime;
          maxTime = waterContainer[0][i].isolateEndTime;
        } else {
          if(minTime > waterContainer[0][i].isolateStartTime){
            minTime = waterContainer[0][i].isolateStartTime;
          }
          if(maxTime < waterContainer[0][i].isolateEndTime){
            maxTime = waterContainer[0][i].isolateEndTime;
          }
        }
      }
      print(minTime);
      print(maxTime);
      print(maxTime - minTime);
    }
  }
  
  endTime(){
    for(int i = 0; i < testSize; i++){
      if(landContainer[0][i].heightMap == null){
        check = false;
      }
    }
    if(check == false){
      check = true;
      new Future.delayed(const Duration(milliseconds: 15), endTime);
    }else{
      //genTime = new DateTime.now().difference(startTime).inMilliseconds.abs();
      //print(genTime);
      //print("end");
    }
  }
  
  //creates the first tile in the system, based on performance recompute terrian state in order to best perfrom
  initState() {
    /*baseLand = new land_tile();
    baseLand.initLand(gl, baseSystemSize, 0, 0);
    secondLand = new land_tile();
    secondLand.initLand(gl, 65, 0, 1);*/

    landContainer = new List();
    for (int i = 0; i < 100; i++) {
      landContainer.add(new List<land_tile>());
      for (int j = 0; j < 100; j++) {
        landContainer[i].add(null);
      }
    }
    
    waterContainer = new List();
    for (int i = 0; i < 100; i++) {
      waterContainer.add(new List());
      for (int j = 0; j < 100; j++) {
        waterContainer[i].add(null);
      }
    }

    
    for(int i = 0; i < testSize; i++){
      landContainer[0][i] = new land_tile();
      landContainer[0][i].initLand(gl, baseSystemSize, 0, i);
    }
    
    //endTime();


    
   
    

   /* landContainer[0][0] = new land_tile();
    landContainer[0][0].initLand(gl, baseSystemSize, 0, 0);

    landContainer[0][1] = new land_tile();
    landContainer[0][1].initLand(gl, 65, 0, 1);

    landContainer[1][0] = new land_tile();
    landContainer[1][0].initLand(gl, 65, 1, 0);

    landContainer[1][1] = new land_tile();
    landContainer[1][1].initLand(gl, 33, 1, 1);*/
    
    /*landContainer[0][2] = new land_tile();
    landContainer[0][2].initLand(gl, 33, 0, 2);
    
    landContainer[2][0] = new land_tile();
    landContainer[2][0].initLand(gl, 33, 2, 0);
    
    landContainer[1][2] = new land_tile();
    landContainer[1][2].initLand(gl, 65, 1, 2);
    
    landContainer[2][1] = new land_tile();
    landContainer[2][1].initLand(gl, 65, 2, 1);*/
    startTime = new DateTime.now();
    initWater();
  }

  //compute the initial state of the scene, which best suits the device
  setup() {
    initState();
  }
bool waterReady = true;
  update() {
    
    camera.update();
    for(int i = 0; i < testSize; i++){
      if(waterContainer[0][i] != null){
        waterContainer[0][i].update();
        avg[i] = waterContainer[0][i].isolateEndTime;
      }
    }
    for(int i = 0; i < testSize; i++){
      if(avg[i] == null){
        waterReady = false;
      }
    }
    
    if(waterReady){
      double avg2 = 0.0;
      for(int i = 0; i < testSize; i++){
        avg2 = avg2 + avg[i].toDouble();
      }
      avg2 = avg2 / testSize;
      //window.console.log(avg2);
    }
    
    waterReady = true;
  }

  List edgeIncrease(List edge) {
    List tempEdge = new List();

    for (int i = 0; i < 65; i++) {
      tempEdge.add(10.0);
    }

    return tempEdge;
  }

  List edgeReduce(List edge) {
    List tempEdge = new List(65);

    for (int i = 0; i < 64; i++) {
      tempEdge[i] = (edge[i * 2] + edge[(i * 2) + 1]) / 2;
    }
    tempEdge[64] = edge[128];

    return tempEdge;
  }

  makeEdge() {
    List topEdge = new List<double>();
    List botEdge = new List<double>();
    List iPlusOne = new List<double>();
    List iMinusOne = new List<double>();

    for (int i = 0; i < 100; i++) {
      for (int j = 0; j < 100; j++) {
        if (landContainer[i][j] != null) {
          print("I:$i , J:$j");
          topEdge = null;
          botEdge = null;
          iPlusOne = null;
          iMinusOne = null;

          //this tile is ready and has data
          //check to make the top edge, where y is max. This requires a tile above to exist
          if (j + 1 <= 100) {
            if (landContainer[i][j + 1] != null) {
              topEdge = new List<double>();
              List edgeOne = new List();
              List edgeTwo = new List();
              for (int k = 0; k < landContainer[i][j + 1].res; k++) {
                edgeOne.add(landContainer[i][j + 1].heightMap[k][1]);
              }
              for (int k = 0; k < landContainer[i][j].res; k++) {
                edgeTwo.add(landContainer[i][j].heightMap[k][
                    landContainer[i][j].res - 2]);
              }

              if (edgeOne.length > 65) {
                edgeOne = edgeReduce(edgeOne);
              } else if (edgeOne.length < 65) {
                edgeOne = edgeIncrease(edgeOne);
              }

              if (edgeTwo.length > 65) {
                edgeTwo = edgeReduce(edgeTwo);
              } else if (edgeTwo.length < 65) {
                edgeTwo = edgeIncrease(edgeTwo);
              }

              for (int k = 0; k < 65; k++) {
                double temp = (edgeTwo[k] + edgeOne[k]) / 2;
                topEdge.add(temp);
              }
            }
          }
          if (j - 1 >= 0) {
            if (landContainer[i][j - 1] != null) {
              botEdge = new List<double>();
              List edgeOne = new List();
              List edgeTwo = new List();
              for (int k = 0; k < landContainer[i][j - 1].res; k++) {
                edgeOne.add(landContainer[i][j - 1].heightMap[k][
                    landContainer[i][j - 1].res - 2]);
              }
              for (int k = 0; k < landContainer[i][j].res; k++) {
                edgeTwo.add(landContainer[i][j].heightMap[k][1]);
              }

              if (edgeOne.length > 65) {
                edgeOne = edgeReduce(edgeOne);
              } else if (edgeOne.length < 65) {
                edgeOne = edgeIncrease(edgeOne);
              }

              if (edgeTwo.length > 65) {
                edgeTwo = edgeReduce(edgeTwo);
              } else if (edgeTwo.length < 65) {
                edgeTwo = edgeIncrease(edgeTwo);
              }

              for (int k = 0; k < 65; k++) {
                double temp = (edgeTwo[k] + edgeOne[k]) / 2;
                botEdge.add(temp);
              }
            }
          }

          if (i + 1 <= 100) {
            if (landContainer[i + 1][j] != null) {
              iMinusOne = new List<double>();
              List edgeOne = new List();
              List edgeTwo = new List();

              for (int k = 0; k < landContainer[i + 1][j].res; k++) {
                edgeOne.add(landContainer[i + 1][j].heightMap[k][1]);
              }
              for (int k = 0; k < landContainer[i][j].res; k++) {
                edgeTwo.add(landContainer[i][j].heightMap[k][landContainer[i][j].res -2]);
              }

              if (edgeOne.length > 65) {
                edgeOne = edgeReduce(edgeOne);
              } else if (edgeOne.length < 65) {
                edgeOne = edgeIncrease(edgeOne);
              }

              if (edgeTwo.length > 65) {
                edgeTwo = edgeReduce(edgeTwo);
              } else if (edgeTwo.length < 65) {
                edgeTwo = edgeIncrease(edgeTwo);
              }

              for (int k = 0; k < 65; k++) {
                double temp = (edgeTwo[k] + edgeOne[k]) / 2;

                iMinusOne.add(temp);
              }
            }
          }

          if (i - 1 >= 0) {
            if (landContainer[i - 1][j] != null) {
              iPlusOne = new List();
              List edgeOne = new List();
              List edgeTwo = new List();

              for (int k = 0; k < landContainer[i - 1][j].res; k++) {
                edgeOne.add(landContainer[i - 1][j].heightMap[k][
                    landContainer[i - 1][j].res - 2]);
              }
              for (int k = 0; k < landContainer[i][j].res; k++) {
                edgeTwo.add(landContainer[i][j].heightMap[k][1]);
              }

              if (edgeOne.length > 65) {
                edgeOne = edgeReduce(edgeOne);
              } else if (edgeOne.length < 65) {
                edgeOne = edgeIncrease(edgeOne);
              }

              if (edgeTwo.length > 65) {
                edgeTwo = edgeReduce(edgeTwo);
              } else if (edgeTwo.length < 65) {
                edgeTwo = edgeIncrease(edgeTwo);
              }

              for (int k = 0; k < 65; k++) {
                double temp = (edgeTwo[k] + edgeOne[k]) / 2;

                iPlusOne.add(temp);
              }
            }
          }
/*
          List testEdge = new List();

          for (int k = 0; k < 65; k++) {
            testEdge.add(-10.0);
          }
          if (topEdge == null) {
            print("top");
          }
          if (botEdge == null) {
            print("botEdge");
          }
          if (iPlusOne == null) {
            print("iPlusOne");
          }
          if (iMinusOne == null) {
            print("iMinusOne");
          }*/
          landContainer[i][j].makeEdges(iMinusOne, iPlusOne, botEdge, topEdge);
        }
      }
    }
  }

  draw() {
    gl.clear(
        RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);

    Matrix4 viewMat = camera.getViewMat();

    gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);
    
    for(int i = 0; i < 100; i++){
      for(int j = 0; j < 100; j++){
        if(landContainer[i][j] != null && waterContainer[i][j] != null){
          landContainer[i][j].draw(viewMat, projectionMat);
          waterContainer[i][j].draw(viewMat, projectionMat);
        }
      }
    }
  }
}
