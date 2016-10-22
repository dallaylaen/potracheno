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
    sess_id varchar(43) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created INT -- unix time
);

CREATE TABLE watch (
    watch_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INT NOT NULL,
    issue_id INT NOT NULL,
    created INT -- unix time
);

CREATE TABLE tag (
    tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(20) NOT NULL,
    descr varchar(4096),
    created INT -- unix time
);

CREATE TABLE issue_tag (
    issue_tag_id INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    created INT -- unix time
);
