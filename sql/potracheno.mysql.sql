DROP TABLE IF EXISTS user;
CREATE TABLE user (
    user_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    name varchar(20) UNIQUE,
    password varchar(256),
    created INT -- unix time
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS issue;
CREATE TABLE issue (
    issue_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    summary varchar (256) NOT NULL,
    body varchar(4096) NOT NULL,
    user_id INT,
    status_id INT default 1,
    created INT -- unix time
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS activity;
CREATE TABLE activity (
    activity_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    issue_id INT NOT NULL,
    seconds INT,
    fix_estimate INT,
    note varchar(4096),
    created INT -- unix time
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS sess;
CREATE TABLE sess (
    sess_id varchar(43) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created INT -- unix time
) DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS watch;
CREATE TABLE watch (
    watch_id INTEGER PRIMARY KEY AUTO_INCREMENT,
    user_id INTEGER NOT NULL,
    issue_id INTEGER NOT NULL,
    created INT -- unix time
);
