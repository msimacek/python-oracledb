-- Default database username
def user = "pythondemo"

-- Default database connection string
def connect_string = "localhost/orclpdb"

-- Prompt for the password
accept pw char prompt 'Enter database password for &user: ' hide