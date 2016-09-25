CREATE TABLE user (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(20) UNIQUE,
    password varchar(256),
    created INT -- unix time
);

CREATE TABLE issue (
    issue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    summary varchar (256) NOT NULL,
    body varchar(4096) NOT NULL,
    user_id INT,
    status_id INT default 1,
    created INT -- unix time
);

CREATE TABLE activity (
    activity_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INT NOT NULL,
    issue_id INT NOT NULL,
    seconds INT,
    fix_estimate INT,
    note varchar(4096),
    created INT -- unix time
);

CREATE TABLE sess (
    sess_id varchar(22) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created INT -- unix time
);
