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
    status_id INT default 1, -- doesn't address any table, statuses are conf'ed
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

CREATE TABLE reset_request (
    reset_request_id INTEGER PRIMARY KEY AUTOINCREMENT,
    reset_key varchar(80) UNIQUE NOT NULL,
    user_id INT NOT NULL,
    expires INT NOT NULL, --unix time
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

-- hand written indices
CREATE UNIQUE INDEX index__watch__user_id__issue_id ON watch (user_id,issue_id);
CREATE INDEX index__activity__seconds ON activity(seconds);
CREATE INDEX index__activity__fix_estimate ON activity(fix_estimate);
CREATE UNIQUE INDEX index__reset_request__reset_key ON reset_request(reset_key);
CREATE INDEX index__reset_request__user_id ON reset_request(user_id);

-- autogenerated indices (table + something_id)
CREATE INDEX index__issue__user_id ON issue (user_id);
CREATE INDEX index__issue__status_id ON issue (status_id);
CREATE INDEX index__activity__user_id ON activity (user_id);
CREATE INDEX index__activity__issue_id ON activity (issue_id);
CREATE INDEX index__sess__user_id ON sess (user_id);
CREATE INDEX index__watch__issue_id ON watch (issue_id);
CREATE INDEX index__issue_tag__issue_id ON issue_tag (issue_id);
CREATE INDEX index__issue_tag__tag_id ON issue_tag (tag_id);

-- autogenerated indices on time (only issue & activity)
CREATE INDEX index__issue__created ON issue (created);
CREATE INDEX index__activity__created ON activity (created);
CREATE INDEX index__reset_request__expires ON reset_request (expires);
