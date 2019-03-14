//
//  WeatherTableViewController.swift
//  URLSessionDataDelegate
//
//  Created by Instructor on 3/13/19.
//  Copyright © 2019 Instructor. All rights reserved.
//

import UIKit;

class WeatherTableViewController: UITableViewController, URLSessionDataDelegate {
    
    var days: [Day] = [Day]();   //The model is an array of instances, initially empty.
    
    private lazy var session: URLSession = {
        let configuration: URLSessionConfiguration = URLSessionConfiguration.default;
        configuration.waitsForConnectivity = true;
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil);
    }();
    
    var receivedData: Data? = Data(); //for all downloaded data, initially empty
    
    let formatter: DateFormatter = DateFormatter();

    override func viewDidLoad() {
        super.viewDidLoad();
        
        formatter.dateStyle = .full;
        let string: String = "https://api.openweathermap.org/data/2.5/forecast/daily";
        
        guard let baseURL: URL = URL(string: string) else {
            fatalError("could not create URL from string \"\(string)\"");
        }
        print("baseURL = \(baseURL)");
        
        let query: [String: String] = [
            "q":     "10003,US", //New York City
            "cnt":   "7",        //number of days
            "units": "imperial", //fahrenheit, not celsius
            "mode":  "json",     //vs. xml or html
            "APPID": "532d313d6a9ec4ea93eb89696983e369"
        ];
        
        guard let url: URL = baseURL.withQueries(query) else {
            fatalError("could not add queries to base URL");
        }
        print("    url = \(url)");
        print();
        
        let task: URLSessionTask = session.dataTask(with: url); //only 1 argument, no closure
        task.resume();
        
        // Uncomment the following line to preserve selection between presentations
        // clearsSelectionOnViewWillAppear = false;

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // navigationItem.rightBarButtonItem = editButtonItem;
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return days.count;
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "WeatherCell", for: indexPath);

        // Configure the cell...
        let day: Day = days[indexPath.row];
        cell.textLabel!.text = formatter.string(from: day.date);
        cell.detailTextLabel!.text = "\(day.temperature)° F";
        cell.imageView!.image = UIImage(named: day.icon)!;
        return cell;
    }
    
    // MARK: - Protocol URLSessionDataDelegate
    // Must pass either .cancel, .allow, or .becomeDownload to the completionHandler.
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let response: HTTPURLResponse = response as? HTTPURLResponse else {
            print("urlSession(_:dataTask:didReceive:completionHandler) did not receive HTTPURLResponse");
            completionHandler(.cancel);
            return;
        }
        
        print("urlSession(_:dataTask:didReceive:completionHandler) received \(response.allHeaderFields.count) response headers:");
        response.allHeaderFields.forEach {print("\t\($0.key): \($0.value)");}
        print();

        //Two ways to find the content length:
        
        if let contentLength: String = response.allHeaderFields["Content-Length"] as? String {
            print("contentLength = \(contentLength)");
        }
        print("response.expectedContentLength = \(response.expectedContentLength)");
        print();
        
        guard (200 ..< 300).contains(response.statusCode) else {
            print("urlSession(_:dataTask:didReceive:completionHandler) received statusCode \(response.statusCode)");
            completionHandler(.cancel);
            return;
        }
        
        guard let mimeType: String = response.mimeType else {
            print("urlSession(_:dataTask:didReceive:completionHandler) did not receive a mimeType");
            completionHandler(.cancel);
            return;
        }
        
        guard mimeType == "application/json" else {
            print("mimeType = \(mimeType)");
            completionHandler(.cancel);
            return;
        }

        completionHandler(.allow);
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("urlSession(_:dataTask:didReceive:), received another \(data)");
        receivedData?.append(data);
    }
    
    // MARK: - Protocol URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        if let error: Error = error {
            fatalError("urlSession(_:task:didCompleteWithError:), error = \(error)");
        }
        
        guard let receivedData: Data = receivedData else {
            fatalError("urlSession(_:task:didCompleteWithError:), receivedData is nil");
        }
        
        print("urlSession(_:task:didCompleteWithError:), received a total of \(receivedData)");
        
        let dictionary: [String: Any];
        do {
            try dictionary = JSONSerialization.jsonObject(with: receivedData) as! [String: Any];
        } catch {
            fatalError("could not create dictionary: \(error)");
        }
        
        let week: [[String: Any]] = dictionary["list"] as! [[String: Any]]; //an array of dictionaries
        
        for day in week {   //day is a [String: Any]
            let dt: Int = day["dt"] as! Int;
            let date: Date = Date(timeIntervalSince1970: TimeInterval(dt));
            let dateString: String = self.formatter.string(from: date);
            
            let temp: [String: NSNumber] = day["temp"] as! [String: NSNumber];
            let max: NSNumber = temp["max"]!;
            
            let weathers: [[String: Any]] = day["weather"] as! [[String: Any]];
            let weather: [String: Any] = weathers[0];
            let icon: String = weather["icon"] as! String;
            
            print("\(dateString) \(max.floatValue)° F \(icon).png");
            self.days.append(Day(date: date, temperature: max.floatValue, icon: icon))
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData();
        }
    }
}
