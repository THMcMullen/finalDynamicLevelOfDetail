library core;

import 'dart:html';
import 'dart:web_gl';
import 'dart:async';

import 'package:vector_math/vector_math.dart';

import 'camera.dart' as cam;
import 'land_tile.dart';
import 'water.dart';

class core{
 
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
  
  List landContainer;
  
  //what all tiles base the size on
  int baseSystemSize = 129;

  core(RenderingContext gGl, CanvasElement gCanvas){
    gl = gGl;
    canvas = gCanvas;
        
    //setup camera and projection matrix
    camera = new cam.camera(canvas);
    projectionMat = makePerspectiveMatrix(45, (canvas.width / canvas.height), 1, 10000);
    setPerspectiveMatrix(projectionMat, 45, (canvas.width / canvas.height), 1.0, 10000.0);

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
  
  initWater(){
    if( landContainer[0][0].heightMap == null || landContainer[0][1].heightMap == null){
      new Future.delayed(const Duration(milliseconds: 15), initWater); 
    } else {
      baseWater = new water(gl,  landContainer[0][0].heightMap, 0, 0, 1);
      secondWater = new water(gl, landContainer[0][1].heightMap, 0, 1, 1);
      makeEdge();
    }
  }
  
  //creates the first tile in the system, based on performance recompute terrian state in order to best perfrom 
  initState(){
    /*baseLand = new land_tile();
    baseLand.initLand(gl, baseSystemSize, 0, 0);
    secondLand = new land_tile();
    secondLand.initLand(gl, 65, 0, 1);*/
    
    landContainer = new List();
    for(int i = 0; i < 100; i++){
      landContainer.add(new List<land_tile>());
      for(int j = 0; j < 100; j++){
        landContainer[i].add(null);
      }
    }
    
    landContainer[0][0] = new land_tile();
    landContainer[0][0].initLand(gl, baseSystemSize, 0, 0);
    
    landContainer[0][1] = new land_tile();
    landContainer[0][1].initLand(gl, 65, 0, 1);
    
    
    initWater();
  }
  
  //compute the initial state of the scene, which best suits the device
  setup(){
    initState();
   
  }
  
  update(){
    camera.update();
    if(baseWater != null){
      baseWater.update();
    }
    if(secondWater != null){
      secondWater.update();
    }
  }
  
  List edgeIncrease(List edge){
    
    
    return edge;
  }
  
  List edgeReduce(List edge){
    
    List tempEdge = new List(65);
    
    for(int i = 0; i < 64; i++){
      tempEdge[i] = (edge[i*2] + edge[(i*2)+1])/2;
    }
    tempEdge[64] = edge[128];
    
    return tempEdge;
  }
  
  makeEdge(){

    List topEdge = new List<double>();
    
    for(int i = 0; i < 1; i++){
      for(int j = 0; j < 1; j++){
        if(landContainer[i][j] != null){
          topEdge = null;
          //this tile is ready and has data
          //check to make the top edge, where y is max. This requires a tile above to exist
          if(landContainer[i][j+1] != null){
            topEdge = new List<double>();
            List edgeOne = new List();
            List edgeTwo = new List();
            for(int k = 0; k < landContainer[i][j+1].res; k++){
              edgeOne.add(landContainer[i][j+1].heightMap[k][landContainer[i][j+1].res - 1]);
            }
            for(int k = 0; k < landContainer[i][j].res; k++){
              edgeTwo.add(landContainer[i][j].heightMap[k][landContainer[i][j].res-1]);
            }

            if(edgeOne.length > 65){
              print("edgeOne is reduced");
            }else if(edgeOne.length < 65){
              print("edgeOne is increased");
              
            }
            
            if(edgeTwo.length > 65){
              print("edgeTwo is reduced");
              
              edgeTwo = edgeReduce(edgeTwo);
              
            }else if(edgeTwo.length < 65){
              print("edgeTwo is increased");
              
            }
            
            
            print(edgeTwo);
            for(int k = 0; k < 65; k++){
              double temp = (edgeOne[k] + edgeTwo[k])/2;
              
              topEdge.add(temp);
            }
            
            print("edgeOne : $edgeOne");
            print("edgeTwo : $edgeTwo");
          }
          
          landContainer[i][j].makeEdges(null,topEdge,null,null);
          landContainer[0][1].makeEdges(topEdge,null,null,null);
        }
        
      }
    }
    
    
  }
  
  draw(){
    
    gl.clear(RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);
    
    Matrix4 viewMat = camera.getViewMat();
    
    gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);
    
    landContainer[0][0].draw(viewMat, projectionMat);
    landContainer[0][1].draw(viewMat, projectionMat);
    if(baseWater != null && secondWater != null){
      //baseWater.draw(viewMat, projectionMat);
      //secondWater.draw(viewMat, projectionMat);
    }
  }
}



















