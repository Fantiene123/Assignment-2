import ballerina/http;
import ballerina/time;

// In-memory storage for programmes
map<Programme> programmes = {};

service /v1 on new http:Listener(8080) {
    # Retrieve all programmes
    #
    # + return - Successful operation 
    resource function get programmes() returns Inline_response_200 {
        return { programmes: programmes };
    }

    # Add a new programme
    #
    # + payload - New programme details
    # + return - Programme created successfully or BadRequest
    resource function post programmes(@http:Payload ProgrammeInput payload) returns Programme|http:BadRequest {
        if (programmes.hasKey(payload.programmeCode)) {
            return <http:BadRequest>{ body: "Programme with this code already exists" };
        }
        Programme newProgramme = <Programme>payload.clone();
        programmes[payload.programmeCode] = newProgramme;
        return newProgramme;
    }

    # Get a programme by code
    #
    # + programmeCode - The programme code 
    # + return - Programme or NotFound
    resource function get programmes/[string programmeCode]() returns Programme|http:NotFound {
        if (programmes.hasKey(programmeCode)) {
            return programmes.get(programmeCode);
        }
        return <http:NotFound>{ body: "Programme not found" };
    }

    # Update a programme
    #
    # + programmeCode - The programme code 
    # + payload - Updated programme details
    # + return - Updated Programme or NotFound
    resource function put programmes/[string programmeCode](@http:Payload ProgrammeInput payload) returns Programme|http:NotFound {
        if (programmes.hasKey(programmeCode)) {
            Programme updatedProgramme = <Programme>payload.clone();
            programmes[programmeCode] = updatedProgramme;
            return updatedProgramme;
        }
        return <http:NotFound>{ body: "Programme not found" };
    }

    # Delete a programme
    #
    # + programmeCode - The programme code 
    # + return - NoContent if deleted or NotFound
    resource function delete programmes/[string programmeCode]() returns http:NoContent|http:NotFound {
        if (programmes.hasKey(programmeCode)) {
            _ = programmes.remove(programmeCode);
            return <http:NoContent>{};
        }
        return <http:NotFound>{ body: "Programme not found" };
    }

    # Get programmes due for review
    #
    # + return - Programmes due for review
    resource function get programmes/due\-for\-review() returns Inline_response_200|error {
        map<Programme> dueForReview = {};
        time:Utc currentDate = time:utcNow();

        foreach var programme in programmes {
            time:Utc registrationDate = check time:utcFromString(programme.registrationDate);
            
            // Calculate the difference in years
            int diffInSeconds = <int>time:utcDiffSeconds(currentDate, registrationDate);
            int yearsDiff = diffInSeconds / (365 * 24 * 60 * 60);
            
            if (yearsDiff >= 5) {
                dueForReview[programme.programmeCode] = programme;
            }
        }

        return { programmes: dueForReview };
    }
 
    # Get programmes by faculty
    #
    # + facultyName - The name of the faculty 
    # + return - Programmes in the faculty or NotFound
    resource function get programmes/by\-faculty/[string facultyName]() returns Inline_response_200|http:NotFound {
        map<Programme> facultyProgrammes = {};

        foreach var programme in programmes {
            if (programme.facultyName == facultyName) {
                facultyProgrammes[programme.programmeCode] = programme;
            }
        }

        if (facultyProgrammes.length() > 0) {
            return { programmes: facultyProgrammes };
        }
        return <http:NotFound>{ body: "No programmes found for this faculty" };
    }
}

