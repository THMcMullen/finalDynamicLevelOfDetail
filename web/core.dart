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
  load(){
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
  //create the skybox texture
  loadTextures(){
    skyBox = gl.createTexture();
    gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);
    for(int i = 0; i < images.length; i++){
      gl.texImage2D(TEXTURE_CUBE_MAP_POSITIVE_X + 1, 0, RGBA, RGBA, UNSIGNED_BYTE, images[i]);
    }
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_MAG_FILTER, LINEAR);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_MIN_FILTER, LINEAR);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
    gl.texParameteri(TEXTURE_CUBE_MAP, TEXTURE_WRAP_T, CLAMP_TO_EDGE); 
    
    print("textures loaded");
  }
  
  initWater(){
    if(baseLand.heightMap == null){
      new Future.delayed(const Duration(milliseconds: 15), initWater); 
    } else {
      baseWater = new water(gl, baseLand.heightMap, 0, 0, 1);
    }
  }
  
  //creates the first tile in the system, based on performance recompute terrian state in order to best perfrom 
  initState(){
    baseLand = new land_tile();
    baseLand.initLand(gl, baseSystemSize, 0, 0);
    
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
  }
  
  draw(){
    
    gl.clear(RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);
    
    Matrix4 viewMat = camera.getViewMat();
    
    gl.bindTexture(TEXTURE_CUBE_MAP, skyBox);
    
    baseLand.draw(viewMat, projectionMat);
    if(baseWater != null){
      baseWater.draw(viewMat, projectionMat);
    }
  }
}



















