/*******************************************************************************
 * Licensed Materials - Property of IBM
 * (c) Copyright IBM Corporation 2020. All Rights Reserved.
 *
 * Note to U.S. Government Users Restricted Rights:
 * Use, duplication or disclosure restricted by GSA ADP Schedule
 * Contract with IBM Corp.
 *******************************************************************************/
/* eslint-disable id-length */
/* eslint max-len: 0 */


"use strict";

const async = require("async");
const request = require("request");

// provide category id
const CATEGORY_ID = "19852f12-9981-4fef-9129-89616d6ba3c4";
const USERNAME = "admin";
const PASSWORD = "password";
const SERVER_URL = "";

function run() {
	process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

	let accessToken = null;
	async.waterfall([
		function(callback) {
			_login(callback);
		},
		function(results, callback) {
			accessToken = results;
			_deleteTermsInCategory(results, CATEGORY_ID, callback);
		}
	], function(err) {
		if (err) {
			console.log(err);
		} else {
			console.log("Finish");
		}
	});
}

function _login(callback) {
	const url = `${SERVER_URL}/v1/preauth/validateAuth`;

	console.log(`Logging into: ${url}`);

	const getOptions = {
		url,
		json: true,
		headers: {
			username: USERNAME,
			password: PASSWORD
		}
	};

	request.get(getOptions, function(err, response, bodyResp) {
		console.log(bodyResp);
		if (err) {
			callback(err);
			return;
		}

		if (bodyResp) {
			callback(null, bodyResp.accessToken);
		}

	});
}

function _deleteTermsInCategory(accessToken, categoryId, callback) {

	console.log("Performing search to find all terms in category");
	const body = {
		"size": 25,
		"from": 0,
		"_source": [
			"artifact_id",
			"metadata.artifact_type",
			"metadata.name",
			"metadata.description",
			"categories",
			"entity.artifacts"
		],
		"query": {
			"bool": {
				"filter": {
					"bool": {
						"minimum_should_match": 1,
						"should": [
							{
								"term": {
									"categories.primary_category_id": categoryId
								}
							},
							{
								"term": {
									"categories.secondary_category_ids": categoryId
								}
							}
						],
						"must_not": {
							"terms": {
								"metadata.artifact_type": [
									"category"
								]
							}
						}
					}
				}
			}
		},
		"sort": [
			{
				"metadata.name.keyword": {
					"order": "asc"
				}
			}
		]
	};

	const url = `${SERVER_URL}/v3/search`;

	const postOptions = {
		url,
		json: true,
		headers: {
			"Authorization": "Bearer " + accessToken,
			"Content-Type": "application/json",
			"Accepts": "application/json"
		},
		body
	};

	request.post(postOptions, function(err, response, bodyResp) {
		if (err) {
			callback(err);
			return;
		}

		if (bodyResp) {
			console.log(`Found ${bodyResp.size} items`);

			async.each(
					bodyResp.rows,
					function(row, callback2) {
						if (row) {
							const artifactId = row.entity.artifacts.artifact_id;
							const versionId = row.entity.artifacts.version_id;
							console.log(`Deleting term - name:${row.metadata.name} version_id:${versionId} artifact_id:${artifactId}`);
							_deleteTerm(accessToken, artifactId, versionId, callback2)
						}
					}, function(err2) {
						if (err2) {
							callback(err2);
							return;
						}

						callback();
					});
		}
	});
}

function _getDraftTerm(accessToken, artifactId, callback) {
	const url = `${SERVER_URL}/v3/glossary_terms/${artifactId}/versions/?status=DRAFT`;

	const options = {
		url,
		json: true,
		headers: {
			"Authorization": "Bearer " + accessToken,
			"Content-Type": "application/json",
			"Accepts": "application/json"
		},
	};

	request.get(options, function(err, response, bodyResp) {
		console.log(`Getting draft term ${artifactId}`);

		if (err) {
			callback(err);
			return;
		}

		if(bodyResp && bodyResp.resources && bodyResp.resources[0]) {
			const versionId = bodyResp.resources[0].metadata.version_id;
			_approveWorkflow(accessToken, artifactId, versionId, callback);
	}

	});
}

function _approveWorkflow(accessToken, artifactId, versionId, callback) {
	const url = `${SERVER_URL}/v3/workflow_user_tasks?artifact_id=${artifactId}&version_id=${versionId}`;

	const options = {
		url,
		json: true,
		headers: {
			"Authorization": "Bearer " + accessToken,
			"Content-Type": "application/json",
			"Accepts": "application/json"
		},
	};

	request.get(options, function(err, response, bodyResp) {
		console.log(`Getting user task for ${artifactId}`);

		if (err) {
			callback(err);
			return;
		}

		if(bodyResp && bodyResp.resources && bodyResp.resources[0]) {
			const taskId = bodyResp.resources[0].metadata.task_id;

			const url = `${SERVER_URL}/v3/workflow_user_tasks/${taskId}/actions`;

			const options2 = {
				url,
				json: true,
				headers: {
					"Authorization": "Bearer " + accessToken,
					"Content-Type": "application/json",
					"Accepts": "application/json"
				},
				body: {
					"action": "complete",
					"form_properties": [
						{
							"id": "action",
							"value": "#publish"
						}
					]
				}
			};

			request.post(options2, function(err2) {
				console.log(`Appproving workflow for ${artifactId}`);

				if (err2) {
					callback(err2);
					return;
				}

				if (callback) {
					callback();
				}
			});
		}
	});
}

function _deleteTerm(accessToken, artifactId, versionId, callback) {
	const url = `${SERVER_URL}/v3/glossary_terms/${artifactId}/versions/${versionId}`;

	const options = {
		url,
		json: true,
		headers: {
			"Authorization": "Bearer " + accessToken,
			"Content-Type": "application/json",
			"Accepts": "application/json"
		},
	};

	request.delete(options, function(err) {
		if (err) {
			callback(err);
			return;
		}

		console.log(`Marking asset for deleting: ${artifactId}`);

		_getDraftTerm(accessToken, artifactId, callback);
	});
}

run();