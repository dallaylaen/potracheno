CREATE TABLE user (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(20) UNIQUE,
    password varchar(256)
);

CREATE TABLE issue (
    issue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    summary varchar (256) NOT NULL,
    body varchar(4096) NOT NULL,
    user_id INT,
    created INT -- unix time
);

CREATE TABLE activity (
    activity_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INT NOT NULL,
    issue_id INT NOT NULL,
    seconds INT NOT NULL,
    note varchar(4096),
    created INT -- unix time
);

CREATE TABLE sess (
    sess_id varchar(22) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created INT -- unix time
);
