class InstanceJoinerRunner < JobRunner


  def self.instance_for(job)
    if job.job_type == "instance_joiner_job"
      self.new(job)
    else
      nil
    end
  end

  def join_instances( record )
      @job.write_output( "Processing record : #{record.id}" ) 
  
      grouped_instances = case record
                    when Resource 
                      Instance.filter(:resource_id => record.id ).select_hash_groups(:instance_type_id, :id).values
                    else
                      Instance.filter(:archival_object_id => record.id ).select_hash_groups(:instance_type_id, :id).values
                    end

      grouped_instances.each do |instances|
        if instances.length > 1
          @job.write_output( "Multiple instances with same type found for record : #{record.id}" ) 
          containers = Container.filter( :instance_id => instances ).limit(3).all
          master = containers.shift
          containers2delete = []
          instances2delete = []
          containers.each_with_index do | container, i|
            pos = i + 2
            type = "type_#{pos}=".intern
            indicator = "indicator_#{pos}=".intern
            
            master.send( type, container.type_1 )
            master.send( indicator, container.indicator_1 )

            containers2delete << container.id
            instances2delete << container.instance_id
          
          end
            
          master.save 
          
          Container.filter(:id => containers2delete).delete 
          Instance.filter(:id => instances2delete).delete 

        end
      end
      
      record.children.each do |child|
        join_instances(child)
      end
  
  end 
  
  def run
    super

    job_data = @json.job

    begin
      DB.open( DB.supports_mvcc?, 
             :retry_on_optimistic_locking_fail => true ) do
        begin
          RequestContext.open( :current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do  

            @job.write_output( "Starting instance joiner job on repo : #{@job.repo_id}" ) 
            
            Resource.filter(:repo_id => @job.repo_id).each do | resource | 
              @job.write_output(" working on #{resource.id} ") 
              join_instances(resource)
            end

          end 
        rescue Exception => e
          terminal_error = e
          @job.write_output(terminal_error.message)
          @job.write_output(terminal_error.backtrace)
          raise Sequel::Rollback
        end
      end
    
    rescue
      terminal_error ||= $!
    end
 
    if terminal_error
      @job.write_output(terminal_error.message)
      @job.write_output(terminal_error.backtrace)
      
      raise terminal_error
    end
    
    @job.write_output("done..")

  end

end
