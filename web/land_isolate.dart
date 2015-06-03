library land_isolate;

import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);
  
  //tells where we are located on the grid
  int locX;
  int locY;
  //resolution this tile should be
  int res;
  List heightMap;
  List vertices;
  List indices;
  int pos; 
  
  //create the heightmap, then the vertices and indices to go with it
  init(data){
    res = data[1];
    locX = data[2];
    locY = data[3];
    heightMap = new List(res);
    for (int i = 0; i < res; i++) {
      heightMap[i] = new List(res);
      for (int j = 0; j < res; j++) {
        heightMap[i][j] = 0.0;
      }
    }
    
    //set height Map to be around a given level
    heightMap[0][0]         = 10.0;
    heightMap[res-1][0]     = 10.0;
    heightMap[0][res-1]     = 10.0;
    heightMap[res-1][res-1] = 10.0;
    
    var height = 10;
    var rng = new math.Random(locX + locY + 82);
    
    int sideLength2 = res - 1; 
    //diamond square implemtation
    for (int sideLength = res - 1; sideLength >= 2; sideLength = sideLength ~/ 2, height /= 2) {

      int halfSide = sideLength ~/ 2;
      int halfSide2 = sideLength2 ~/ 2;
      int QSide2 = halfSide2 ~/ 2;

      for (int x = 0; x < res - 1; x += sideLength) {
        for (int y = 0; y < res - 1; y += sideLength) {
          double avg = heightMap[x][y] + heightMap[x + sideLength][y] + heightMap[x][y + sideLength] + heightMap[x + sideLength][y + sideLength];
          avg /= 4.0;
          double offset = (-height) + rng.nextDouble() * (height - (-height));
          heightMap[x + halfSide][y + halfSide] = avg + offset;
        }
      }
      for (int x = 0; x < res; x += halfSide) {
        for (int y = (x + halfSide) % sideLength; y < res; y += sideLength) {
          double avg = heightMap[(x - halfSide + res) % res][y] + heightMap[(x + halfSide) % res][y] + heightMap[x][(y + halfSide) % res] + heightMap[x][(y - halfSide + res) % res];
          avg /= 4.0;
          double offset = (-height) + rng.nextDouble() * (height - (-height));
          heightMap[x][y] = avg + offset;
        }
      }
    }
    //heightMap is ready to be sent back, but first create the inside vertices and indices
    indices = new List();
    for(int i = 0; i < res-3; i++){//minus 3 so to allow the avoidance of creating the indices for the outside edges
      for(int j = 0; j < res-3; j++){
        //the possition of the vertic in the indice array we want to draw.
        pos = (i*(res-2)+j);
        indices.add(pos);
        indices.add(pos+1);
        indices.add(pos+res-2);
        indices.add(pos+res-2);
        indices.add(pos+res+1-2);
        indices.add(pos+1);
      }
    }
    vertices = new List();
    for(int i = 1; i < res-1; i++){
      for(int j = 1; j < res-1; j++){
        vertices.add(i * (128 / (res - 1)) + (128 * locX));
        vertices.add(heightMap[i][j]);
        vertices.add(j * (128 / (res - 1)) + (128 * locY));       
      }
    }
    sendPort.send(["init", heightMap, indices, vertices]);
  }
  
  //once a comand has been sent, proccess it and return the needed changes
  receivePort.listen((msg) {
    if(msg[0] == "init"){
      init(msg);
    }
  });
}