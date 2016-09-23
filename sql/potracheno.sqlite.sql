CREATE TABLE user (
    user_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name varchar(20) UNIQUE,
    password varchar(256)
);

CREATE TABLE article (
    article_id INTEGER PRIMARY KEY AUTOINCREMENT,
    summary varchar (256) NOT NULL,
    body varchar(4096) NOT NULL,
    author_id INT,
    posted INT -- unix time
);

CREATE TABLE time_spent (
    time_spent_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INT NOT NULL,
    article_id INT NOT NULL,
    seconds INT NOT NULL,
    note varchar(4096),
    posted INT -- unix time
);

CREATE TABLE sess (
    sess_id varchar(22) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created INT -- unix time
);
