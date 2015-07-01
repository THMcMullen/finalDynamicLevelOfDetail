// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:web_gl';
import 'dart:async';

import 'core.dart';

//The start
//Main launchs "core" and calls for the initilization of the scene
//Once a scene is initilized, the updating cycle and render loop can then be used
void main() {
  //Select the canvas as our rneder tatget
  CanvasElement canvas = querySelector("#render-target"); 
  //canvas.requestFullscreen();
  RenderingContext gl = canvas.getContext3d();

  var nexus = new core(gl, canvas);
    
  //set up the enviroment
  nexus.setup();
  
  logic(){  
    new Future.delayed(const Duration(milliseconds: 15), logic);
    nexus.update();
  }

  render(time){
    window.requestAnimationFrame(render);
    nexus.draw(); 
  }

  logic();
  render(1);

}
