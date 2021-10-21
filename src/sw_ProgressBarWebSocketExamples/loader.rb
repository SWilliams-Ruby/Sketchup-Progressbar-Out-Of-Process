require File.join(SW::ProgressBarWebSocketExamples::PLUGIN_DIR, 'progress_bar_websocket_example1.rb')


module SW
  module ProgressBarWebSocketExamples
    def self.load_menus()
          
      # Load Menu Items  
      if !@loaded
        toolbar = UI::Toolbar.new "SW ProgressBarWebSocketExamples"
        
        cmd = UI::Command.new("Progress1") {SW::ProgressBarWebSocketExamples.demo1}
        cmd.large_icon = cmd.small_icon =  File.join(SW::ProgressBarWebSocketExamples::PLUGIN_DIR, "icons/example1.png")
        cmd.tooltip = "ProgressBarWebSocket"
        cmd.status_bar_text = "Example 1"
        toolbar = toolbar.add_item cmd
       
        toolbar.show
      @loaded = true
      end
    end
    load_menus()
  end
  
end


