# ArchivesSpace Instance Joiner Plugin

This plugin will take all resource and archival_object records and combine all
the associated containers with the same instance type together into one single
instance and delete all the other instances and containers.

# Why? 

EAD does not have the concept of an instance, and for awhile the EAD importer
took container tags in the EAD and created multiple instances, instead of a
single instance with multiple container values. 

## To Install:

1. Download and unpack the plugin to your ArchivesSpace plugins directory. Be sure
that the directory is called "instance_joiner" ( remove "-master" or any other
branch information added by Github )
2. Add "instance_joiner" to your config/config.rb AppConfig[:plugins] list
3. Restart ArchivesSpace

## To Use:

**It is strongly recommended that you backup your database before running this
process**. Records will be modified and deleted in bulk, so it's critical that you
review all your records after running this to ensure that the data is correct.

* Logged in as a repository administrator, go to Plugins --> Instance Joiner. 
* Click submit and all the records in the selected repository will be modified.

## To Uninstall:

You will need to remove any job record in your database that point to this:
```
DELETE FROM job WHERE job_type_id = ( SELECT id from enumeration_value WHERE
value = 'instance_joiner_job' ); )
```

And you might as well delete the enumeration value as well: 
```
DELETE FROM enumeration_value WHERE value = 'instance_joiner_job';
```

Then remove the instance_joiner_job value from your config/config.rb
AppConfig[:plugins] list. 


