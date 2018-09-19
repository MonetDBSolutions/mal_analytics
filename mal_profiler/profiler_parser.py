# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import json
import logging
import monetdblite as mdbl


LOGGER = logging.getLogger(__name__)


class ProfilerObjectParser:
    def __init__(self, db):
        self._event_id = 0
        self._heartbeat_id = 0
        self._execution_id = 0
        self._variable_id = 0
        self._states = {'start': 0, 'done': 1, 'pause': 2}
        self._db = db

    def _parse_trace(self, json_object):
        '''Parses a trace object and adds it in the database

        '''
        self._execution_id += 1
        self._event_id += 1
        # Extract the mal execution
        execution_data = {
            'execution_id': self._execution_id,
            'server_session': json_object.get('session'),
            'tag': json_object.get('tag')
        }
        mdbl.insert('mal_execution', execution_data, client=self._db)

        exec_state = self._states.get(json_object.get('state'))
        event_data = {
            'mal_execution_id': self._execution_id,
            'pc': json_object.get('pc'),
            'execution_state': exec_state,
            'clk': json_object.get('clk'),
            'ctime': json_object.get('ctime'),
            'thread': json_object.get('thread'),
            'mal_function': json_object.get('function'),
            'usec': json_object.get('usec'),
            'rss': json_object.get('rss'),
            'type_size': json_object.get('size'),
            'long_statement': json_object.get('stmt'),
            'short_statement': json_object.get('short')
        }
        mdbl.insert('profiler_event', event_data, client=self._db)

        # Process prerequisite events.
        for prereq in json_object.get('prereq'):
            mdbl.insert(
                'prerequisite_events',
                {
                    'prerequisite_event': prereq,
                    'consequent_event': self._event_id,
                },
                client=self._db)

        # The algorithm to process a variable list is exactly the
        # same for returns and for arguments, so we should not be
        # duplicating code.
        var_list_tables = {
            'ret': 'return_variable_list',
            'arg': 'argument_variable_list'
        }
        for var_list_field in ('ret', 'arg'):
            var_list = json_object.get(var_list_field, list())
            stmt1 = mdbl.prepare('SELECT variable_id FROM mal_variable WHERE name=?')
            stmt2 = mdbl.prepare('SELECT type_id FROM mal_type WHERE name=?')
            for var in var_list:
                # Have we encountered this variable before?
                r = stmt1.execute(var['name'])
                # r = mdbl.sql(
                #   'select variable_id from mal_variable where name={}'.format(var['name']),
                #   client=self._db
                # )
                if len(r['variable_id']) == 0:
                    # Nope, first time we see this
                    # variable. Insert it into the variables
                    # table.
                    self._variable_id += 1
                    r = stmt2.execute(var['type'])
                    # r = mdbl.sql(
                    #     'select type_id from mal_type where name={}'.format(var['type']),
                    #     client=self._db
                    # )
                    if len(r['type_id']) == 0:
                        LOGGER.warning('Unkown type: {}'.format(var['type']))
                        LOGGER.warning('Ignoring variable: {}'.format(var['name']))
                        continue
                    type_id = r['type_id'][0]
                    variable_data = {
                        'name': var.get('name'),
                        'mal_execution_id': self._execution_id,
                        'alias': var.get('alias'),
                        'type_id': type_id,
                        'is_persistent': var.get('kind') == 'persistent',
                        'bid': var.get('bid'),
                        'var_count': var.get('count'),
                        'var_size': var.get('size'),
                        'seqbase': var.get('seqbase'),
                        'hghbase': var.get('hghbase'),
                        'eol': var.get('eol') == 0
                    }
                    mdbl.insert('mal_variable', variable_data, client=self._db)
                    current_var_id = self._variable_id
                else:
                    # Yup, make a note of the variable id.
                    current_var_id = r['variable_id'][0]

                var_list_data = {
                    'variable_list_index': var.get('index'),
                    'event_id': self._event_id,
                    'variable_id': current_var_id
                }

                mdbl.insert(var_list_tables[var_list_field], var_list_data, client=self._db)

    def _parse_heartbeat(self, json_object):
        '''Parses a heartbeat object and adds it to the database.

        '''
        self._heartbeat_id += 1
        data_keys = ('server_session',
                     'clk',
                     'ctime',
                     'rss',
                     'nvcsw')
        data = {(k, json_object.get(k)) for k in data_keys}
        mdbl.insert('heartbeat', data, client=self._db)
        for c in json_object['cpuload']:
            mdbl.insert(
                'cpuload',
                {'heartbeat_id': self._heartbeat_id, 'val': c},
                client=self._db
            )

    def parse_object(self, json_string):
        try:
            json_object = json.loads(json_string)
        except json.JSONDecodeError as json_error:
            LOGGER.warning("W001: Cannot parse object")
            LOGGER.warning(json_string)
            LOGGER.warning("Decoder reports %s", json_string)
            return

        dispatcher = {
            'trace': self._parse_trace,
            'heartbeat': self._parse_heartbeat
        }

        source = json_object.get('source')
        if source is None:
            LOGGER.error("Unkown JSON object")
            LOGGER.error("%s", json_object['source'])
            return

        try:
            dispatcher[source](json_object)
        except KeyError:
            # TODO raise exception
            LOGGER.error("Unkown JSON object kind: %s", json_object['source'])
            return
