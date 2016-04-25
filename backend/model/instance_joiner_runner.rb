class InstanceJoinerRunner < JobRunner


  def self.instance_for(job)
    if job.job_type == "instance_joiner_job"
      self.new(job)
    else
      nil
    end
  end

  def join_instances( record )
     joined = false # we haven't done anything yet.. 
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
          joined = true 
        end
      end
      
      joined
  end 
  
  def run
    super

    begin
      DB.open( DB.supports_mvcc?, 
             :retry_on_optimistic_locking_fail => true ) do
        begin
          RequestContext.open( :current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do  

            @job.write_output( "Starting instance joiner job on repo : #{@job.repo_id}" ) 
            updated_records = []  
            
            import_job_enum = EnumerationValue.filter(:value => "import_job").get(:id)
            Job.filter( :job_type_id => import_job_enum, :repo_id => @job.repo_id ).select(:id).each do |j|
              JobCreatedRecord.filter( :job_id => j.id ).select(:record_uri).each do |record|
                target_record = nil 
                parsed = JSONModel.parse_reference(record.record_uri)
                case parsed[:type]
                when "archival_object"
                  target_record = ArchivalObject[parsed[:id].to_i]
                when "resource" 
                  target_record = Resource[parsed[:id].to_i] 
                else
                  next
                end
                
                next unless target_record # sometimes records get deleted but their created record job row persists... 
                
                @job.write_output(" working on #{parsed[:type]} #{record.record_uri} ") 
                joined = join_instances(target_record)
                updated_records << record.record_uri if joined 
              end
            end
           
            @job.record_created_uris(updated_records.uniq) 

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
