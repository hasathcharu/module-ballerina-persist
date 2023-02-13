import ballerina/persist as _;

type Building record {|
    readonly string buildingCode;
    string city;
    string state;
    string country;
    string postalCode;
    Workspace[] workspaces1;
    Workspace[] workspaces2;
|};

type Workspace record {|
    readonly string workspaceId;
    string workspaceType;
    Building building;
|};

type Building1 record {|
    readonly string buildingCode;
    string city;
    string state;
    string country;
    string postalCode;
    Workspace2[] workspaces;
|};

type Workspace2 record {|
    readonly string workspaceId;
    string workspaceType;
    Building1 location1;
    Building1 location2;
|};