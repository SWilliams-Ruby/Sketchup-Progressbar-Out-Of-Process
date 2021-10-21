# An Out-Of-Process Progressbar

In which we explore the possibility of implementing a 'Cancel' button to interrupt long running Sketchup Operations.

Implemented via:
- A multi-threaded Ruby TCPServer running in the Sketchup process
- a Custom WebSocket implementataion
- the Chrome Browser running in Application mode
- and utility Javascript functions



![600](https://user-images.githubusercontent.com/88683212/138324512-61a03287-117e-47b3-8759-9785583626e8.gif)
