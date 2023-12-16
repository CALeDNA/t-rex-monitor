import psycopg2
import sys
import re
from datetime import datetime
from configparser import ConfigParser

sensitive_patterns = [
    r'(AWS_ACCESS_KEY_ID=)([^\s]+)',
    r'(AWS_SECRET_ACCESS_KEY=)([^\s]+)',
    r'(AWS_DEFAULT_REGION=)([^\s]+)',
    r'(AWS_S3_ACCESS_KEY_ID=)([^\s]+)',
    r'(AWS_S3_SECRET_ACCESS_KEY=)([^\s]+)',
    r'(AWS_S3_DEFAULT_REGION=)([^\s]+)',
    r'(AWS_S3_BUCKET=)([^\s]+)'
]

flavors = {
    "/tmp/ben-ecopcr": "m3.large",
    "/tmp/ben-blast": "m3.large",
    "/tmp/ben-ac": "m3.large",
    "/tmp/ben-newick": "m3.large",
    "/tmp/ben-tronko": "m3.xl",
    "/tmp/ben-qc": "m3.large",
    "/tmp/ben-assign": "m3.large",
    "/tmp/ben-assignxl": "m3.xl",
}

def scrub_command(command, sensitive_patterns):
    for pattern in sensitive_patterns:
        command = re.sub(pattern, r'\1REDACTED', command)
    return command

def config(filename='database.ini', section='postgresql'):
    # create a parser
    parser = ConfigParser()
    # read config file
    parser.read(filename)

    # get section, default to postgresql
    db = {}
    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))

    return db

def update_job_queue(queue,socket):
    """ Connect to the PostgreSQL database server """
    conn = None
    try:
        # read connection parameters
        params = config()

        # connect to the PostgreSQL server
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**params)
		
        # create a cursor
        cur = conn.cursor()

        result=[]
        current_entry={}
        with open(queue, 'r') as file:
            for line in file:
                line = line.strip()

                if line == '[job]':
                    if current_entry:
                        result.append(current_entry)
                    current_entry = {}
                else:
                    key, value = line.split('=', 1)
                    if key.strip() == "command":
                        value = scrub_command(value.strip(' "'), sensitive_patterns)
                    current_entry[key.strip()] = value
            
            # Append the last entry after the loop
            if current_entry:
                result.append(current_entry)
            
            # print(result[0])

            for entry in result:
                if(entry["type"] == "done"):
                    start_time = datetime.strptime(entry["start_time"], '%Y-%m-%d %H:%M:%S')
                    stop_time = datetime.strptime(entry["stop_time"], '%Y-%m-%d %H:%M:%S')
                    time_difference = stop_time - start_time

                    job_data = {
                        'job_id': entry["id"],
                        'output_dir': entry["stdout_path"],
                        'job_name': entry["name"],
                        'status': entry["type"],
                        'node_id': entry["ran_id"],
                        'server': entry["ran_name"],
                        'duration': time_difference,
                        'durationSeconds': time_difference.total_seconds(),
                        'node_name': entry["ran_name"],
                        'socket': socket,
                        'executedAt': start_time,
                        'instanceType': flavors[socket],
                        'command': entry["command"],
                    }
                elif(entry["type"] == "running"):
                    start_time = datetime.strptime(entry["start_time"], '%Y-%m-%d %H:%M:%S')
                    job_data = {
                        'job_id': entry["id"],
                        'output_dir': entry["stdout_path"],
                        'job_name': entry["name"],
                        'status': entry["type"],
                        'node_id': entry["running_id"],
                        'server': entry["running_name"],
                        'duration': "-1",
                        'durationSeconds': None,
                        'node_name': entry["ran_name"],
                        'socket': socket,
                        'executedAt': start_time,
                        'instanceType': flavors[socket],
                        'command': entry["command"]
                    }
                else:
                    job_data = {
                        'job_id': entry["id"],
                        'output_dir': entry["stdout_path"],
                        'job_name': entry["name"],
                        'status': entry["type"],
                        'node_id': "-1",
                        'server': "WAITING",
                        'duration': "-1",
                        'durationSeconds': None,
                        'node_name': "WAITING",
                        'socket': socket,
                        'executedAt': "WAITING",
                        'instanceType': flavors[socket],
                        'command': entry["command"]
                    }

                try:
                    insert_query = '''
                        INSERT INTO "SchedulerJobs" (job_id, output_dir, job_name, status, node_id, server, node_name, duration, durationSeconds, executedAt, instanceType, socket, command)
                        VALUES (%(job_id)s, %(output_dir)s, %(job_name)s, %(status)s, %(node_id)s, %(server)s, %(node_name)s, %(duration)s, %(durationSeconds)s, %(executedAt)s, %(instanceType)s, %(socket)s, %(command)s)
                        ON CONFLICT (job_name) DO UPDATE
                        SET
                            output_dir = EXCLUDED.output_dir,
                            status = CASE WHEN "SchedulerJobs".status <> EXCLUDED.status THEN EXCLUDED.status ELSE "SchedulerJobs".status END,
                            node_id = EXCLUDED.node_id,
                            server = EXCLUDED.server,
                            node_name = EXCLUDED.node_name,
                            duration = (
                                (
                                    (
                                        "SchedulerJobs".duration::interval +
                                        EXCLUDED.duration::interval
                                    )::time
                                )::text
                            ),
                            durationSeconds = COALESCE("SchedulerJobs".durationSeconds, 0.0) + EXCLUDED.durationSeconds,
                            executedAt = EXCLUDED.executedAt,
                            instanceType = EXCLUDED.instanceType,
                            socket = EXCLUDED.socket,
                            command = EXCLUDED.command
                        WHERE "SchedulerJobs".status <> EXCLUDED.status;
                        '''
                    cur.execute(insert_query, job_data)
                    conn.commit()
                except Exception as e:
                    print(f"Error inserting data: {e}")
                    conn.rollback()
       
	# close the communication with the PostgreSQL
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
            print('Database connection closed.')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Please provide the path to the queue file and ben socket.")
        sys.exit(1)
    
    queue = sys.argv[1]
    socket= sys.argv[2]
    update_job_queue(queue,socket)
