library water_isolate;

import 'dart:isolate';
import 'dart:async';
import 'dart:math' as math;
import 'contour_tracing.dart';
import 'package:vector_math/vector_math.dart';

main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  int startTime;
  
  bool init = false;
  var grid;
  double waterLevel = -0.5;
  double dt = 0.01;

  List g;
  List b;
  List h, h1;
  List u, u1;
  List v, v1;

  List indMap;
  List nHeight;

  int X;
  int Y;
  int locX;
  int locY;

  void copy(List orignal, List update) {
    for (int i = 0; i < orignal.length; i++) {
      orignal[i] = update[i];
    }
  }

  void upwind(type) {
    var t = new List<double>(X * Y);

    int x1, x2, y1, y2;
    double u_xy, v_xy;

    // Loop through each point
    for (int iy = 0; iy < Y; iy++) {
      int yp1 = iy + 1;
      int ym1 = iy - 1;
      for (int ix = 0; ix < X; ix++) {
        int xp1 = ix + 1;
        int xm1 = ix - 1;
        // Select a certain array
        switch (type) {
          case 0:
            // h
            // Don't update a boundary
            if (b[iy * X + ix] == true) {
              t[iy * X + ix] = h[iy * X + ix];
              break;
            }

            // Calculate velocity
            u_xy = (u[iy * X + ix] + u[iy * X + xp1]) / 2.0;
            v_xy = (v[iy * X + ix] + v[yp1 * X + ix]) / 2.0;

            // Horizontal coordinates
            x1 = (u_xy < 0) ? xp1 : ix;
            x2 = (u_xy < 0) ? ix : xm1;

            // Vertical coordinates
            y1 = (v_xy < 0) ? yp1 : iy;
            y2 = (v_xy < 0) ? iy : ym1;

            // Advected value
            t[iy * X + ix] = h[iy * X + ix] -
                ((u_xy * (h[iy * X + x1] - h[iy * X + x2])) +
                        (v_xy * (h[y1 * X + ix] - h[y2 * X + ix]))) *
                    dt;

            break;
          case 1:
            // u
            // Don't update a boundary
            if (b[iy * X + ix] == true) {
              t[iy * X + ix] = u[iy * X + ix];
              break;
            }

            // Calculate velocity
            u_xy = u[iy * X + ix];
            v_xy = (v[iy * X + xm1] +
                    v[iy * X + ix] +
                    v[yp1 * X + xm1] +
                    v[yp1 * X + ix]) /
                4.0;

            // Horizontal coordinates
            x1 = (u_xy < 0) ? xp1 : ix;
            x2 = (u_xy < 0) ? ix : xm1;

            // Vertical coordinates
            y1 = (v_xy < 0) ? yp1 : iy;
            y2 = (v_xy < 0) ? iy : ym1;

            // Advected value
            t[iy * X + ix] = u[iy * X + ix] -
                ((u_xy * (u[iy * X + x1] - u[iy * X + x2])) +
                        (v_xy * (u[y1 * X + ix] - u[y2 * X + ix]))) *
                    dt;
            break;
          case 2:
            // v
            // Don't update a boundary
            if (b[iy * X + ix] == true) {
              t[iy * X + ix] = v[iy * X + ix];
              break;
            }

            // Calculate velocity
            u_xy = (u[ym1 * X + ix] +
                    u[ym1 * X + xp1] +
                    u[iy * X + ix] +
                    u[iy * X + xp1]) /
                4.0;
            v_xy = v[iy * X + ix];

            // Horizontal coordinates
            x1 = (u_xy < 0) ? xp1 : ix;
            x2 = (u_xy < 0) ? ix : xm1;

            // Vertical coordinates
            y1 = (v_xy < 0) ? yp1 : iy;
            y2 = (v_xy < 0) ? iy : ym1;

            // Advected value
            t[iy * X + ix] = v[iy * X + ix] -
                ((u_xy * (v[iy * X + x1] - v[iy * X + x2])) +
                        (v_xy * (v[y1 * X + ix] - v[y2 * X + ix]))) *
                    dt;
            break;
        }
      }
    }

    switch (type) {
      case 0:
        copy(h, t);
        break;
      case 1:
        copy(u, t);
        break;
      case 2:
        copy(v, t);
        break;
    }
  }


  update() {

    upwind(0);
    upwind(1);
    upwind(2);
    
    // Update h
    //#pragma omp parallel for
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        // Temporary variables
        double u_yx;
        double u_yxp1;
        double v_yx;
        double v_yp1x;

        // Don't update boundaries
        if (b[iy * X + ix] == false) {
          // Velocity across a boundary is zero
          if (b[iy * X + ix - 1] == true) {
            u_yx = 0.0;
          } else {
            u_yx = u[iy * X + ix];
          }

          // Velocity across a boundary is zero
          if (b[iy * X + ix + 1] == true) {
            u_yxp1 = 0.0;
          } else {
            u_yxp1 = u[iy * X + ix + 1];
          }

          // Velocity across a boundary is zero
          if (b[(iy - 1) * X + ix] == true) {
            v_yx = 0.0;
          } else {
            v_yx = v[iy * X + ix];
          }

          // Velocity across a boundary is zero
          if (b[(iy + 1) * X + ix] == true) {
            v_yp1x = 0.0;
          } else {
            v_yp1x = v[(iy + 1) * X + ix];
          }

          // Update the Height
          h[iy * X + ix] = h[iy * X + ix] +
              0.5 * h[iy * X + ix] * ((u_yx - u_yxp1) + (v_yx - v_yp1x)) * dt;
        } else {
          h[iy * X + ix] = 0.0;
        }
      }
    }

    // Update U
    //#pragma omp parallel for
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        // Don't update boundaries
        if (b[iy * X + ix] == false) {
          if (b[iy * X + ix - 1] == true) {
            u[iy * X + ix] = 0.0;
          } else {
            u[iy * X + ix] = u[iy * X + ix] +
                (0.98 *
                    ((g[iy * X + ix - 1] + h[iy * X + ix - 1]) -
                        (g[iy * X + ix] + h[iy * X + ix])) *
                    dt);
          }
        } else {
          u[iy * X + ix] = 0.0;
        }
      }
    }

    //Update V
    //#pragma omp parallel for
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        // Don't update boundaries
        if (b[iy * X + ix] == false) {
          if (b[(iy - 1) * X + ix] == true) {
            v[iy * X + ix] = 0.0;
          } else {
            v[
                iy * X + ix] =
                v[iy * X + ix] +
                    (0.98 *
                        ((g[(iy - 1) * X + ix] + h[(iy - 1) * X + ix]) -
                            (g[iy * X + ix] + h[iy * X + ix])) *
                        dt);
          }
        } else {
          v[iy * X + ix] = 0.0;
        }
      }
    }
    
    int m = 1;
    if(X == 33){
      m = 4;
    }else if(X == 65){
      m = 2;
    }
    
    //List norm = new List();
    List nHeight = new List<double>();
    
    for(int i = 0; (i < grid.length); i++){
      for(int j = 0; (j < grid[i].length); j++){
        if(grid[i][j] != 0){//current location is water
          nHeight.add(((j.toDouble()) * m) + (locX*128));
          nHeight.add((h[i * X + j]) + 5.0);
          nHeight.add(((i.toDouble()) * m) + (locY*128));
        }
      }
    }

    
    //print("sending data");
    sendPort.send(["update", nHeight]);
  }

  waterSetup() {
    g = new List<double>(X * Y);
    b = new List<bool>(Y * X);
    h = new List<double>(X * Y);
    h1 = new List<double>(X * Y);
    u = new List<double>(X * Y);
    u1 = new List<double>(X * Y);
    v = new List<double>(X * Y);
    v1 = new List<double>(X * Y);

    // Boundaries
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        if (ix == 0 || iy == 0 || ix == X - 1 || iy == Y - 1) {
          b[iy * X + ix] = true;
        } else {
          b[iy * X + ix] = false;
        }
      }
    }
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        if (grid[iy][ix] == 0) {
          b[iy * X + ix] = true;
        }
      }
    }

    // Ground
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        g[iy * X + ix] = 0.0;
        //g[iy*X + ix] = iy * 0.2;
      }
    }

    // Height
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        h[iy * X + ix] = 0.0;
        h1[iy * X + ix] = h[iy * X + ix];
      }
    }

    // Horizontal Velocity
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        u[iy * X + ix] = 0.0;
        u1[iy * X + ix] = 0.0;
      }
    }

    // Vertical Velocity
    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {
        v[iy * X + ix] = 0.0;
        v1[iy * X + ix] = 0.0;
      }
    }

    for (int iy = 0; iy < Y; iy++) {
      for (int ix = 0; ix < X; ix++) {

        double r = math.sqrt((ix - X / 2) * (ix - X / 2) + (iy - Y / 2) * (iy - Y / 2));

        if (r > Y / 2) {
          r = (r / (Y / 2)) * 4;
          double PI = 3.14159;
          h[iy * X + ix] += Y * (1 / math.sqrt(2 * PI)) * math.exp(-(r * r) / 2) + (1/r);

          //h[iy*X + ix] += ((Y/4) - r) * ((Y/4) - r);
        }
        
        h[iy * X + ix] = 15.0;
      }
    }

    //update();
    //temp();
    init = true;
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

  config() {
    List indices = new List();
    List vert = new List();
    List norm = new List();

    for (int i = 0; i < grid.length; i++) {
      for (int j = 0; j < grid[i].length; j++) {
        if (grid[i][j] != 0) {
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

    for (int i = 0; i < grid.length; i++) {
      for (int j = 0; j < grid[i].length; j++) {
        if (grid[i][j] != 0) {
          if (i + 1 <= grid.length - 1) {
            if (grid[i + 1][j] != 0) {
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
          } else {
            if (grid[i - 1][j] != 0) {
              current = null;
              cm1 = null;
              cp1 = null;
              currentp1 = null;
              for (int k = 0; k < vert.length; k += 3) {
                if (vert[k] == j && vert[k + 2] == i) {
                  current = k ~/ 3;
                } else if (vert[k] == j + 1 && vert[k + 2] == i) {
                  currentp1 = k ~/ 3;
                } else if (vert[k] == j && vert[k + 2] == i - 1) {
                  cm1 = k ~/ 3;
                } else if (vert[k] == j + 1 && vert[k + 2] == i - 1) {
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
    }

    List vertices = new List();
    
    int m = 1;
    if(X == 33){
      m = 4;
    }else if(X == 65){
      m = 2;
    }
    
    for(int i = 0; (i < grid.length); i++){
      for(int j = 0; (j < grid[i].length); j++){
        if(grid[i][j] != 0){//current location is water
          vertices.add(((j.toDouble()) * m) + (locX*128));
          vertices.add(5.0);
          vertices.add(((i.toDouble()) * m) + (locY*128));
        }
      }
    }

    norm = createNormals(indices, vertices);

    sendPort.send(["Init", indices, vertices, norm, startTime]);

    waterSetup();
  }

  initilize(layout) {
    contour_tracing blob;
    blob = new contour_tracing(layout);
    grid = blob.blobMap;

    for (int i = 1; i < grid.length - 1; i++) {
      for (int j = 1; j < grid[i].length - 1; j++) {
        if (grid[i][j] != 0 && grid[i][j] != 200) {
          if (grid[i + 1][j + 1] == 0) {
            grid[i + 1][j + 1] = 200;
          }
          if (grid[i + 1][j] == 0) {
            grid[i + 1][j] = 200;
          }
          if (grid[i + 1][j - 1] == 0) {
            grid[i + 1][j - 1] = 200;
          }
          if (grid[i][j + 1] == 0) {
            grid[i][j + 1] = 200;
          }
          if (grid[i][j - 1] == 0) {
            grid[i][j - 1] = 200;
          }
          if (grid[i - 1][j + 1] == 0) {
            grid[i - 1][j + 1] = 200;
          }
          if (grid[i - 1][j] == 0) {
            grid[i - 1][j] = 200;
          }
          if (grid[i - 1][j - 1] == 0) {
            grid[i - 1][j - 1] = 200;
          }
        }
      }
    }

    config();
  }

  receivePort.listen((msg) {
    
    startTime = new DateTime.now().millisecondsSinceEpoch;
    
    if (init) {
      update();
    } else {
      X = msg[2];
      Y = msg[2];
      locX = msg[3];
      locY = msg[4];
      initilize(msg[1]);
    }
  });
}
