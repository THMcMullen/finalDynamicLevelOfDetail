library contour_tracing;

//traces around the water to find where and how water at the location should act
//returns a list of blobs where water should be
class contour_tracing {
  
  List heightMap;
  List blobMap;
  
  int workingX;
  int workingY;
  
  int dir;
  int turnTries;
  int res;
  int counter = 0;
  
  double level = 5.0;
  
  contour_tracing(List map) {
    //perform a contour trace of the map to find where water is
    
    res = map.length;

    //
    blobMap = new List(res+2);
    for(int i = 0; i < res+2; i++){
      blobMap[i] = new List(res+2);
      for(int j = 0; j < res+2; j++){
        blobMap[i][j] = 0;
      }
    }
    
    heightMap = new List(res+2);
    for(int i = 0; i < res+2; i++){
      heightMap[i] = new List(res+2);
      for(int j = 0; j < res+2; j++){
        if(i == 0 || i == res+1 || j == 0 || j == res+1){
          heightMap[i][j] = 99;
        }else{
          heightMap[i][j] = map[j-1][i-1];
        }
      }
    }

    for (int Oy = 0; Oy < res + 2; Oy++) {
      for (int Ox = 0; Ox < res + 2; Ox++) {
        workingY = Oy;
        workingX = Ox;
        
        if ((heightMap[workingY][workingX] <= level) && (blobMap[workingY][workingX] == 0)) {

          counter++;

          blobMap[workingY][workingX] = counter;

          dir = 2;
          
          do {
            dir = turnLeft(dir);
            turnTries = 0;
            while (move(dir) == false) {
              var Ndir = turnRight(dir);
              turnTries++;
              if (turnTries >= 4) {
                break;
              }
              dir = Ndir;
            }
            if (turnTries >= 4) {
              break;
            }
            if (move(dir)) {
              moveX(dir);
              moveY(dir);
            }

          } while (workingX != Ox || workingY != Oy);

          //break; //part of a found area, skip to the end of it on this row
        } else if (heightMap[workingY][workingX] <= level && blobMap[workingY][workingX] != 0) {
          int temp = blobMap[workingY][workingX];
          for (int z = Ox + 1; z < res + 2; z++) {
            //if we are still in the blob and have not found the end of it
            if (blobMap[Oy][z] != temp) {} else {
              //we have found the end of the blob, so skip x to the end part, and update z to get out of this loop
              Ox = z;
            }
          }
        }
      }
    }   
    //go through the blobMap, and ladscape to full in each blob
    for (int i = 1; i < res + 1; i++) {
      for (int j = 1; j < res + 1; j++) {
        //check that above and left have the same label, and we fit the water condition
        if (blobMap[i - 1][j] != 0 && heightMap[i][j] <= level) {
          blobMap[i][j] = blobMap[i - 1][j];
        } else if (blobMap[i][j - 1] != 0 && heightMap[i][j] <= level) {
          blobMap[i][j] = blobMap[i][j - 1];
        }
      }
    }
    
    List temp = new List(blobMap.length-2);
    for(int i = 0; i < temp.length; i++){
      temp[i] = new List(blobMap.length-2);
    }
    for(int i = 0; i < temp.length; i++){
      for(int j = 0; j < temp.length; j++){
        temp[i][j] = blobMap[i+1][j+1];
      }
    }
    
    blobMap = temp;
   
    
  }

  int turnLeft(var dir) {
    if (dir == 0) {
      dir = 3;
    } else if (dir == 1) {
      dir = 0;
    } else if (dir == 2) {
      dir = 1;
    } else if (dir == 3) {
      dir = 2;
    }
    return dir;
  }

  int turnRight(var dir) {
    if (dir == 0) {
      dir = 1;
    } else if (dir == 1) {
      dir = 2;
    } else if (dir == 2) {
      dir = 3;
    } else if (dir == 3) {
      dir = 0;
    }
    return dir;
  }

  bool move(var dir) {
    bool moving = false;

    if (dir == 0) {
      if (heightMap[workingY - 1][workingX] <= level &&
          ((blobMap[workingY - 1][workingX] == 0) ||
              (blobMap[workingY - 1][workingX] == counter))) {
        moving = true;
      }
    } else if (dir == 1) {
      if (heightMap[workingY][workingX + 1] <= level &&
          ((blobMap[workingY][workingX + 1] == 0) ||
              (blobMap[workingY][workingX + 1] == counter))) {
        moving = true;
      }
    } else if (dir == 2) {
      if (heightMap[workingY + 1][workingX] <= level &&
          ((blobMap[workingY + 1][workingX] == 0) ||
              (blobMap[workingY + 1][workingX] == counter))) {
        moving = true;
      }
    } else if (dir == 3) {
      if (heightMap[workingY][workingX - 1] <= level &&
          ((blobMap[workingY][workingX - 1] == 0) ||
              (blobMap[workingY][workingX - 1] == counter))) {
        moving = true;
      }
    }

    return moving;
  }

  void moveX(dir) {
    //right
    if (dir == 1) {
      if (heightMap[workingY][workingX + 1] <= level) {
        workingX = workingX + 1;
        blobMap[workingY][workingX] = counter;
      }
      //left
    } else if (dir == 3) {
      if (heightMap[workingY][workingX - 1] <= level) {
        workingX = workingX - 1;
        blobMap[workingY][workingX] = counter;
      }
    }
  }
  void moveY(dir) {
    //up
    if (dir == 0) {
      if (heightMap[workingY - 1][workingX] <= level) {
        workingY = workingY - 1;
        blobMap[workingY][workingX] = counter;
      }
      //down
    } else if (dir == 2) {
      if (heightMap[workingY + 1][workingX] <= level) {
        workingY = workingY + 1;
        blobMap[workingY][workingX] = counter;
      }
    }
  }
}
