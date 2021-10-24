
module SW
  module ProgressBarWebSocketExamples
    def self.demo1()
      begin
      #p 'start'

        model = Sketchup.active_model.start_operation('Progress Bar Example', true)

        # Specify the progress bar web page
        dialog_path = File.join(SW::ProgressBarWebSocketExamples::PLUGIN_DIR, 'html/example1_dialog.html')
        
        # Specify a hash of elements that will be passed to the dialog script
        pbar_status = {:operation => "Adding Cubes", :value => 0.0, :label => "Remaining:"}
        
        SW::ProgressBarWebSocket::ProgressBar.new(dialog_path) { |pbar|
          # 10.times { sleep(0.2) }
          # p 'end'
          # return      


          # update the progressbar with initial values
          pbar.refresh(pbar_status)
          
          # create an array of random points 
          points =  []
          1000.times{points << [rand(100),rand(100),rand(100)]}

          # Add cubes to the model, keeping the progress bar updated
          @userstop = false
          points.each_with_index { |point, index|
            make_cube(point)
            if pbar.update?
              pbar_status[:label] = "Remaining: #{points.size - index}"
              pbar_status[:value] = 100 * index / points.size
              result = pbar.refresh(pbar_status)
              # check for commands returned by the dialog
              if result == 'UserStopClicked' 
                @userstop = true
                break
              end
            end
          }
        }

        Sketchup.active_model.commit_operation
        if @userstop
          puts 'Demo stopped by the user'
        else 
          puts 'Demo Completed'
        end

      rescue => exception
        Sketchup.active_model.abort_operation
        # Catch a user initated cancel 
        if exception.is_a? SW::ProgressBarWebSocket::ProgressBarAbort
          #UI.messagebox('Demo Aborted', MB_OK)
          p 'Demo Canceled'
        else
          raise exception
        end
      end

    end
    
    # add a cube to the model  
    def self.make_cube(point)
      ents = Sketchup.active_model.entities
      grp = ents.add_group
      face = grp.entities.add_face [0,0,0],[2,0,0],[2,2,0],[0,2,0]
      face.pushpull(2)
      grp.material = "red"
      tr = Geom::Transformation.new(point)
      grp.transform!(tr)
    end

  end
end
nil

