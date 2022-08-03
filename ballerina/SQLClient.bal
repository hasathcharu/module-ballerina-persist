// Copyright (c) 2022 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/sql;

public client class SQLClient {

    private final sql:Client dbClient;

    private string entityName;
    private sql:ParameterizedQuery tableName;
    private map<FieldMetadata> fieldMetadata;
    private string[] keyFields;

    public function init(string entityName, sql:ParameterizedQuery tableName, map<FieldMetadata> fieldMetadata, string[] keyFields, sql:Client dbClient) returns error? {
        self.entityName = entityName;
        self.tableName = tableName;
        self.fieldMetadata = fieldMetadata;
        self.keyFields = keyFields;
        self.dbClient = dbClient;
    }

    public function runInsertQuery(record {} 'object) returns sql:ExecutionResult|error {
        sql:ParameterizedQuery query = sql:queryConcat(
            `INSERT INTO `, self.tableName, ` (`,
            self.getColumnNames(true), ` ) `,
            `VALUES `, self.getInsertQueryParams('object)
        );
        return check self.dbClient->execute(query);
    }

    // TODO: handle composite keys
    public function runReadByKeyQuery(anydata key) returns record {}|error {
        sql:ParameterizedQuery query = sql:queryConcat(
            `SELECT `, self.getColumnNames(), ` FROM `, self.tableName, ` WHERE `, check self.getGetKeyWhereClauses(key)
        );
        record {}|error result = self.dbClient->queryRow(query);
        if result is sql:NoRowsError {
            return <InvalidKey>error("A record does not exist for '" + self.entityName + "' for key " + key.toBalString() + ".");
        }
        return result;
    }

    public function runReadQuery(map<anydata>|FilterQuery? filter) returns stream<record {}, sql:Error?>|error {
        sql:ParameterizedQuery query = sql:queryConcat(`SELECT `, self.getColumnNames(), ` FROM `, self.tableName);

        if !(filter is ()) {
            query = sql:queryConcat(query, ` WHERE `);
            if filter is FilterQuery {
                query = sql:queryConcat(query, filter);
            } else {
                query = sql:queryConcat(query, check self.getWhereClauses(filter));
            }
        }

        stream<record {}, sql:Error?> resultStream = self.dbClient->query(query);
        return resultStream;
    }

    public function runUpdateQuery(record {} 'object, map<anydata>|FilterQuery? filter) returns error? {
        sql:ParameterizedQuery query = sql:queryConcat(`UPDATE `, self.tableName, ` SET`, check self.getSetClauses('object));

        if !(filter is ()) {
            query = sql:queryConcat(query, ` WHERE`);
            if filter is FilterQuery {
                query = sql:queryConcat(query, ` `, filter);
            } else {
                query = sql:queryConcat(query, check self.getWhereClauses(filter));
            }
        }

        _ = check self.dbClient->execute(query);
    }

    public function runDeleteQuery(map<anydata>|FilterQuery? filter) returns error? {
        sql:ParameterizedQuery query = sql:queryConcat(`DELETE FROM `, self.tableName);

        if !(filter is ()) {
            query = sql:queryConcat(query, ` WHERE`);
            if filter is FilterQuery {
                query = sql:queryConcat(query, ` `, filter);
            } else {
                query = sql:queryConcat(query, check self.getWhereClauses(filter));
            }
        }

        _ = check self.dbClient->execute(query);
    }

    private function getInsertQueryParams(record {} 'object) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery params = `(`;
        string[] keys = self.fieldMetadata.keys();
        int columnCount = 0;
        foreach string key in keys {
            if self.fieldMetadata.get(key).autoGenerated {
                continue;
            }
            if columnCount > 0 {
                params = sql:queryConcat(params, `,`);
            }
            params = sql:queryConcat(params, `${<sql:Value>'object[key]}`);
            columnCount = columnCount + 1;
        }
        params = sql:queryConcat(params, `)`);
        return params;
    }

    private function getColumnNames(boolean skipAutogenerated = false) returns sql:ParameterizedQuery {
        sql:ParameterizedQuery params = ` `;
        string[] keys = self.fieldMetadata.keys();
        int columnCount = 0;
        foreach string key in keys {
            if self.fieldMetadata.get(key).autoGenerated && !skipAutogenerated {
                continue;
            }
            if columnCount > 0 {
                params = sql:queryConcat(params, `, `);
            }
            params = sql:queryConcat(params, stringToParameterizedQuery(self.fieldMetadata.get(key).columnName));
            columnCount = columnCount + 1;
        }
        return params;
    }

    // TODO: handle composite keys (record types)
    private function getGetKeyWhereClauses(anydata key) returns sql:ParameterizedQuery|error {
        map<anydata> filter = {};
        filter[self.keyFields[0]] = key;
        return check self.getWhereClauses(filter);
    }

    function getWhereClauses(map<anydata> filter) returns sql:ParameterizedQuery|error {
        sql:ParameterizedQuery query = ` `;

        string[] keys = filter.keys();
        foreach int i in 0 ..< keys.length() {
            if i > 0 {
                query = sql:queryConcat(query, ` AND `);
            }
            query = sql:queryConcat(query, check self.getFieldParamQuery(keys[i]), ` = ${<sql:Value>filter[keys[i]]}`);
        }
        return query;
    }

    function getSetClauses(record {} 'object) returns sql:ParameterizedQuery|error {
        sql:ParameterizedQuery query = ` `;
        string[] keys = 'object.keys();
        foreach int i in 0 ..< keys.length() {
            if i > 0 {
                query = sql:queryConcat(query, `, `);
            }
            query = sql:queryConcat(query, check self.getFieldParamQuery(keys[i]), ` = ${<sql:Value>'object[keys[i]]}`);
        }
        return query;
    }

    function getFieldParamQuery(string fieldName) returns sql:ParameterizedQuery|FieldDoesNotExist {
        FieldMetadata? fieldMetadata = self.fieldMetadata[fieldName];
        if fieldMetadata is () {
            return <FieldDoesNotExist>error("Field '" + fieldName + "' does not exist in entity '" + self.entityName + "'.");
        }
        return stringToParameterizedQuery(fieldMetadata.columnName);
    }

    function close() returns error? {
        return self.dbClient.close();
    }
}
