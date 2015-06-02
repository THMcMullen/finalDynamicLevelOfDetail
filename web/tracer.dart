import 'dart:isolate';
import 'dart:math' as math;

import 'contour_tracing.dart';
import 'package:vector_math/vector_math.dart';
import 'perlin_noise.dart';

main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);
  
  List waterBodies;
  List offset;
  List static;
  List fluid;
  
  int res;
  
  int numOctaves = 1;
  double change = 1.0;
  
  List createVertices(int index){
    List vertices = new List();
    
    int minX = offset[0][index];
    int minY = offset[2][index];
  
    /*
    sendPort.send("index is: $index");
    for(int i = 0; i < waterBodies[index].length; i++){
      sendPort.send(waterBodies[index][i]);
    }
    */
    //print(minX + waterBodies[index].length-1);
    //print(minY + waterBodies[index][0].length-1);

    for(int i = 0; (i < waterBodies[index].length); i++){
      for(int j = 0; (j < waterBodies[index][i].length); j++){
        if(waterBodies[index][i][j] != 0){//current location is water
          vertices.add(minY + j.toDouble() -1);
          vertices.add(5.0);
          vertices.add(minX + i.toDouble() -1);
        }
      }
    }
    
    
    
    
    //sendPort.send(waterBodies[index].length);
    return vertices;
  }
  
  List createIndices(int index){
    List indices = new List();
    List vert = new List();
    
    List grid = waterBodies[index];
    
    for(int i = 0; i < grid.length; i++){
      for(int j = 0; j < grid[i].length; j++){
        if(grid[i][j] != 0){
          vert.add(j);
          vert.add(5.0);
          vert.add(i);
        }
      }
    }
    
    int current = null;
    int cm1 = null;
    int cp1 = null;
    int currentp1 = null;
    
    for(int i = 0; i < waterBodies[index].length-1; i++){
      for(int j = 0; j < waterBodies[index][i].length-1; j++){
        if (grid[i][j] != 0) {
          if (grid[i+1][j] != 0) {
            current = null;
            cm1 = null;
            cp1 = null;
            currentp1 = null;
            for (int k = 0; k < vert.length; k += 3) {
              if (vert[k] == j && vert[k + 2] == i) {
                current = k ~/ 3;
              } else if (vert[k] == j + 1 && vert[k + 2] == i) {
                currentp1 = k ~/ 3;
              } else if (vert[k] == j && vert[k + 2] == i + 1) {
                cm1 = k ~/ 3;
              } else if (vert[k] == j + 1 && vert[k + 2] == i + 1) {
                cp1 = k ~/ 3;
              }
            }
            if (cp1 == null ||
                cm1 == null ||
                current == null ||
                currentp1 == null) {
              //print("$i:, \n $j:");
            } else {
              indices.add(currentp1);
              indices.add(cm1);
              indices.add(cp1);
              indices.add(current);
              indices.add(currentp1);
              indices.add(cm1);
            }
          }
        }
      }
    }
    
    //print("indices: $indices");
    return indices;
  }
  
  List createNormals(List indices, List vertices){
    
    List normals = new List();
    
    Vector3 pointOne = new Vector3.zero();
    Vector3 pointTwo = new Vector3.zero();
    Vector3 pointThree = new Vector3.zero();
    
    Vector3 U = new Vector3.zero();
    Vector3 V = new Vector3.zero();
    
    for(int i = 0; i < indices.length; i+=3){
      //every 3 indices equals one triangle
      //work out the vector that makes up the first point of the triangle
      pointOne[0] = vertices[(indices[i])*3];
      pointOne[1] = vertices[(indices[i])*3+1];
      pointOne[2] = vertices[(indices[i])*3+2];
      
      pointTwo[0] = vertices[(indices[i+1])*3];
      pointTwo[1] = vertices[(indices[i+1])*3+1];
      pointTwo[2] = vertices[(indices[i+1])*3+2];
      
      pointThree[0] = vertices[(indices[i+2])*3];
      pointThree[1] = vertices[(indices[i+2])*3+1];
      pointThree[2] = vertices[(indices[i+2])*3+2];
      
      U = pointTwo - pointOne;
      V = pointThree - pointOne;
      
      normals.add(((U.y * V.z) - U.z * V.y)* -1.0);
      normals.add(((U.z * V.x) - U.x * V.z)* -1.0);
      normals.add(((U.x * V.y) - U.y * V.x)* -1.0);
    }
    
    return normals;
  }
  
  createFluid(int index){    
    //create the indice
    List indices = createIndices(index);
    //create vertices
    List vertices = createVertices(index);
    //create normals
    List normals = createNormals(indices, vertices);

    fluid.add([indices, vertices, normals]);
  }
  
  createStatic(int index){
    //create the indice
    List indices = createIndices(index);
    //create vertices
    List vertices = createVertices(index);
    //create normals
    List normals = createNormals(indices, vertices);

    static.add([indices, vertices, normals]);
  }
  
  
  creator(){
    int minSize = 15;
    double size = 0.0;
    
    fluid = new List();
    static = new List();
    //sendPort.send(waterBodies.length);
    //go though every blob to create the indices, vertice, and normals
    for(int i = 0; i < waterBodies.length; i++){
      size = ((waterBodies[i].length + waterBodies[i][0].length) / 2);
      if(size > minSize){
        createFluid(i);
      }else if(size > 5){
        createStatic(i);
      }
    }
    
    sendPort.send([fluid, static]);
    
  }

  trace(data){
    contour_tracing blob;
    //create a blob map, containing all bodies of water
    blob = new contour_tracing(data);
    /*print(blob.blobMap.length);
    for(int i = 0; i < blob.blobMap.length; i++){
      print(blob.blobMap[i]); 
    }*/
    //split up each body of water into individual bodies
    
    waterBodies = new List(blob.counter);
    var minX = new List(blob.counter);
    var maxX = new List(blob.counter);
    var minY = new List(blob.counter);
    var maxY = new List(blob.counter);
    //initilise each list
    for(int i = 0; i < blob.counter; i++){
      minX[i] = blob.res;
      maxX[i] = 0;
      minY[i] = blob.res;
      maxY[i] = 0;
    }
    
    //now put each blob into a different blob class
    for(int h = 1; h < blob.counter+1; h++){
      for(int i = 0; i < blob.res; i++){
        for(int j = 0; j < blob.res; j++){
          if(blob.blobMap[i][j] == h){
            if(i < minX[h-1]){
              //new lowest X value
              minX[h-1] = i;
            }
            if(i > maxX[h-1]){
              maxX[h-1] = i;
            }
            if(j < minY[h-1]){
              minY[h-1] = j;
            }
            if(j > maxY[h-1]){
              maxY[h-1] = j;
            }
          }
        }
      }     
    }
    
    (blob.counter);
   //if(blob.blobMap[math.min((i+minX[h]),128)][math.min((j+minY[h]),128)] == h+1){
    
    for(int h = 0; h < blob.counter; h++){
      waterBodies[h] = new List((math.max(((maxX[h]+1) - (minX[h])),1))+2);
      for(int i = 0; i < waterBodies[h].length; i++){
        waterBodies[h][i] = new List((math.max(((maxY[h]+1) - (minY[h])),1))+2);
        for(int j = 0; j < waterBodies[h][i].length; j++){
          waterBodies[h][i][j] = 0;
        }
      }
    }
    for(int h = 0; h < blob.counter; h++){
      for(int i = 1; i < waterBodies[h].length-1; i++){
        for(int j = 1; j < waterBodies[h][i].length-1; j++){
          if(blob.blobMap[(i+minX[h])-1][(j+minY[h])-1] == h+1){
            waterBodies[h][i][j] = 1;
          }
        }
      }
    }
    for(int h = 0; h < blob.counter; h++){
      for(int i = 0; i < waterBodies[h].length; i++){
        for(int j = 0; j < waterBodies[h][i].length; j++){
          if(waterBodies[h][i][j] != 0 && waterBodies[h][i][j] != 200){
            //check to make sure the values added to the blobs do not go outside the range
            //if the max value for x is equal to the res do not let the waterbodies add 200 to that location
            if(minY[h] != 0){//minX is above 0 so we can add the 200 buffer below the data
              if(waterBodies[h][i][j-1] == 0){
                waterBodies[h][i][j-1] = 200;
              }
            }
            if(minX[h] != 0){
              if(waterBodies[h][i-1][j] == 0){
                waterBodies[h][i-1][j] = 200;
              }
            }
            if(maxX[h] < res-1){
              if(waterBodies[h][i+1][j] == 0){
                waterBodies[h][i+1][j] = 200;
              }
            }
            if(maxY[h] < res-1){
              if(waterBodies[h][i][j+1] == 0){
                waterBodies[h][i][j+1] = 200;
              }
            }
            if(minY[h] != 0 && minX[h] != 0){
              if(waterBodies[h][i-1][j-1] == 0){
                waterBodies[h][i-1][j-1] = 200;
              }
            }
            if(maxY[h] < res-1 && maxX[h] <res-1){
              if(waterBodies[h][i+1][j+1] == 0){
                waterBodies[h][i+1][j+1] = 200;
              }
            }
            if(minX[h] != 0 && maxY[h] < res-1){
              if(waterBodies[h][i-1][j+1] == 0){
                waterBodies[h][i-1][j+1] = 200;
              }
            }
            if(minY[h] != 0 && maxX[h] < res-1){
              if(waterBodies[h][i+1][j-1] == 0){
                waterBodies[h][i+1][j-1] = 200;
              }
            }            
          }
        }
      }
    }
    
    blob = null;
    offset = [minX, maxX, minY, maxY];   
    creator();
  }
  
  update(){
    //go through each body of water
    int minSize = 15;
    double size;
    double y = 0.0;
    
    List vertices = new List();
    List verticesContainer = new List();
    
    if(change >= 63.0){
      change -= 63;
    }
    change += 0.001;
    for(int h = 0; h < waterBodies.length; h++){
      //for each water cell only update the water cell height, and not the edge ones (edge ones == 200)
      size = ((waterBodies[h].length + waterBodies[h][0].length) / 2);
      if(size > minSize){//if we are of the size to be fluid....
        int minX = offset[0][h];
        int minY = offset[2][h];
        vertices = new List();
        for(int i = 0; i < waterBodies[h].length; i++){
          for(int j = 0; j < waterBodies[h][i].length; j++){
            if(waterBodies[h][i][j] != 0){
              if(waterBodies[h][i][j] == 200){//is an added edge, create points,b ut do not change the value
                vertices.add(minY + j.toDouble() -1);
                vertices.add(5.0);
                vertices.add(minX + i.toDouble() -1);
              }else{//change the height value
                vertices.add(minY + j.toDouble() -1);
                //now add the new height value
                y = perlinOctaveNoise(minY.toDouble() + i*2/res, minX.toDouble() + j*2/res, change, 1.0, 1+numOctaves, 1.0/math.sqrt(2.0))*50;
                
                vertices.add(y);
                vertices.add(minX + i.toDouble() -1);                
              }
            }
          }
        }
        //add vertices to list here
        verticesContainer.add(vertices);
      }
    }
    sendPort.send(["update", verticesContainer]);
  }
  
  receivePort.listen((msg) {
    //sendPort.send("Recieved Water");
    res = 129;
    if(msg[0] == "init"){
      trace(msg[1]);
    }else if(msg[0] == "update"){
      update();
    }
    
  });
}