package com.restapi.sample;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Map;
import java.util.Scanner;

import org.apache.commons.codec.binary.Base64;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

public class ResApiMain {

	static String ServiceUrl = "https://dev.azure.com/<your_org>/";
	static String TeamProjectName = "your_team_project_name";
	static String UrlEndGetWorkItemById = "/_apis/wit/workitems/";
	static Integer WorkItemId = 1208;
	static String PAT = "your_pat";
	
	public static void main(String[] args) {

		try {
			
			String AuthStr = ":" + PAT;
			Base64 base64 = new Base64();
			
			String encodedPAT = new String(base64.encode(AuthStr.getBytes()));
			
			URL url = new URL(ServiceUrl + TeamProjectName + UrlEndGetWorkItemById + WorkItemId.toString());
			HttpURLConnection con = (HttpURLConnection) url.openConnection();
			
			con.setRequestProperty("Authorization", "Basic " + encodedPAT);
			System.out.println("URL - " + url.toString());
			System.out.println("PAT - " + encodedPAT);
			con.setRequestMethod("GET");
			
			int status = con.getResponseCode();
			
			if (status == 200){
				String responseBody;
				try (Scanner scanner = new Scanner(con.getInputStream())) {
					responseBody = scanner.useDelimiter("\\A").next();
					System.out.println(responseBody);
				}
				
				try {
					Object obj = new JSONParser().parse(responseBody);
					JSONObject jo = (JSONObject) obj;
				
					String WIID = (String) jo.get("id").toString();
					Map<String, String> fields = (Map<String, String>) jo.get("fields");
					System.out.println("WorkItemId - " + WIID);
					System.out.println("WorkItemTitle - " + fields.get("System.Title"));
					//System.out.println("WorkItemId - " + Area);
				} catch (ParseException e) {
				// TODO Auto-generated catch block
					e.printStackTrace();
				}
			}			
			
			con.disconnect();
			
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
		
	}

}
