-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

start transaction;

create table mal_execution (
       execution_id bigint,
       server_session char(36) not null,
       tag int not null,

       constraint pk_mal_execution primary key (execution_id),
       constraint unique_me_mal_execution unique(server_session, tag)
);

create table profiler_event (
       event_id bigint,
       mal_execution_id bigint not null,
       pc int not null,
       execution_state tinyint not null,
       clk bigint,
       ctime bigint,
       thread int,
       mal_function text,
       usec int,
       rss int,
       type_size int,
       long_statement text,
       short_statement text,
       instruction text,
       mal_module text,

       constraint pk_profiler_event primary key (event_id),
       constraint fk_pe_mal_execution_id foreign key (mal_execution_id) references mal_execution(execution_id),
       -- constraint unique_event
       constraint unique_pe_profiler_event unique(mal_execution_id, pc, execution_state)
);

create table prerequisite_events (
       prerequisite_relation_id bigint,
       prerequisite_event bigint,
       consequent_event bigint,

       constraint pk_prerequisite_events primary key (prerequisite_relation_id),
       constraint fk_pre_prerequisite_event foreign key (prerequisite_event) references profiler_event(event_id),
       constraint fk_pre_consequent_event foreign key (consequent_event) references profiler_event(event_id)
);

create table mal_type (
       type_id int,
       tname text,
       base_size int,
       subtype_id int,

       constraint pk_mal_type primary key (type_id),
       constraint fk_mt_subtype_id foreign key (subtype_id) references mal_type(type_id)
);


create table mal_variable (
       variable_id bigint,
       name varchar(20) not null,
       mal_execution_id bigint not null,
       alias text,
       type_id int,  -- change this maybe?
       is_persistent bool,
       bid int,
       var_count int,
       var_size int,
       seqbase int,
       hghbase int,
       eol bool,
       mal_value text,

       constraint pk_mal_variable primary key (variable_id),
       constraint fk_mv_mal_execution_id foreign key (mal_execution_id) references mal_execution(execution_id),
       constraint fk_mv_type_id foreign key (type_id) references mal_type(type_id),
       constraint unique_mv_var_name unique (mal_execution_id, name)
);

create table return_variable_list (
       return_list_id bigint,
       variable_list_index int,
       event_id bigint,
       variable_id bigint,

       constraint pk_return_variable_list primary key (return_list_id),
       constraint fk_rv_event_id foreign key (event_id) references profiler_event(event_id),
       constraint fk_rv_variable_id foreign key (variable_id) references mal_variable(variable_id)
);

create table argument_variable_list (
       argument_list_id bigint,
       variable_list_index int,
       event_id bigint,
       variable_id bigint,

       constraint pk_argument_variable_list primary key (argument_list_id),
       constraint fk_av_event_id foreign key (event_id) references profiler_event(event_id),
       constraint fk_av_variable_id foreign key (variable_id) references mal_variable(variable_id)
);

commit;

start transaction;

create table heartbeat (
       heartbeat_id bigint,
       server_session char(36) not null,
       clk bigint,
       ctime bigint,
       rss int,
       -- Non voluntary context switch
       nvcsw int,

       constraint pk_heartbeat primary key (heartbeat_id)
);

create table cpuload (
       cpuload_id bigint,
       heartbeat_id bigint,
       val decimal(3, 2),

       constraint pk_cpuload primary key (cpuload_id),
       constraint fk_cl_heartbeat_id foreign key (heartbeat_id) references heartbeat(heartbeat_id)
);
commit;


start transaction;
insert into mal_type (type_id, tname, base_size) values ( 1, 'bit', 1);                          -- 1
insert into mal_type (type_id, tname, base_size) values ( 2, 'bte', 1);                          -- 2
insert into mal_type (type_id, tname, base_size) values ( 3, 'sht', 2);                          -- 3
insert into mal_type (type_id, tname, base_size) values ( 4, 'int', 4);                          -- 4
insert into mal_type (type_id, tname, base_size) values ( 5, 'lng', 8);                          -- 5
insert into mal_type (type_id, tname, base_size) values ( 6, 'hge', 16);                         -- 6
insert into mal_type (type_id, tname, base_size) values ( 7, 'oid', 8);                          -- 7
insert into mal_type (type_id, tname, base_size) values ( 8, 'flt', 8);                          -- 8
insert into mal_type (type_id, tname, base_size) values ( 9, 'dbl', 16);                         -- 9
insert into mal_type (type_id, tname, base_size) values (10, 'str', -1);                         -- 10
insert into mal_type (type_id, tname, base_size) values (11, 'date', -1);                        -- 11
insert into mal_type (type_id, tname, base_size) values (12, 'void', 0);                         -- 12
insert into mal_type (type_id, tname, base_size) values (13, 'BAT', 0);                          -- 13
insert into mal_type (type_id, tname, base_size, subtype_id) values (14, 'bat[:bit]', 1, 1);     -- 14
insert into mal_type (type_id, tname, base_size, subtype_id) values (15, 'bat[:bte]', 1, 2);     -- 15
insert into mal_type (type_id, tname, base_size, subtype_id) values (16, 'bat[:sht]', 2, 3);     -- 16
insert into mal_type (type_id, tname, base_size, subtype_id) values (17, 'bat[:int]', 4, 4);     -- 17
insert into mal_type (type_id, tname, base_size, subtype_id) values (18, 'bat[:lng]', 8, 5);     -- 18
insert into mal_type (type_id, tname, base_size, subtype_id) values (19, 'bat[:hge]', 16, 6);    -- 19
insert into mal_type (type_id, tname, base_size, subtype_id) values (20, 'bat[:oid]', 8, 7);     -- 20
insert into mal_type (type_id, tname, base_size, subtype_id) values (21, 'bat[:flt]', 8, 8);     -- 21
insert into mal_type (type_id, tname, base_size, subtype_id) values (22, 'bat[:dbl]', 16, 9);    -- 22
insert into mal_type (type_id, tname, base_size, subtype_id) values (23, 'bat[:str]', -1, 10);   -- 23
insert into mal_type (type_id, tname, base_size, subtype_id) values (24, 'bat[:date]', -1, 11);  -- 24

commit;
