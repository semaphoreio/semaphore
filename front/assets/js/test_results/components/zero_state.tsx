import Icon from "../util/icon";

export const ZeroState = () => {
  return (
    <div className="bg-washed-yellow br3 pa3 pa4-m ba b--black-075 w-100 mt2">
      <h2 className="f3 mb1">Ready to set up Test Reports?</h2>
      <p className="mb4 measure pr6-ns">Reading through thousands lines of logs isn’t fun. <span className="bg-lightest-red ph1 br3">Spot failed tests in seconds</span>, instead of minutes!</p>

      <div className="mb3 relative">
        <div className="absolute dn db-ns" style="top: -65px; left: 480px; transform: rotate(-6deg);">
          <div className="tc">
            <div className="f6 b">Get readable results<br/>in 5 minutes!</div>
            <div className="serif f00 nl4">⤶</div>
          </div>
        </div>
        <div className="bg-white pa3 br3" style="box-shadow: inset 0 1px 3px 0 rgb(0 0 0 / 15%), 0 0 0 1px rgb(0 0 0 / 20%);">
          <div className="flex justify-between mv1">
            <h4 className="f4 mb0 pointer">
              <span className="red select-none">●</span>
                Example Test Suite
              <span className="f6 normal gray ph1">2 Failed, 4 Passed</span>
            </h4>
            <div className="ph2-m">
              <span className="f6 code">
                  00:17<span className="o-60">.232</span>
              </span>
            </div>
          </div>

          <div className="bl b--lighter-gray pl3 ml1 mt2">
            <div className="mb3">
              <div className="flex justify-between bg-red white bt b--white">
                <div className="flex-auto ph2">
                    test users are able to log in
                </div>
                <div className="bl b--white f6 code flex items-center ph2">
                    00:02<span className="o-60">.243</span>
                </div>
              </div>
              <div className="overflow-auto ph2 pv1 bl br bb b--red bw1" style="max-height: 480px;">
                <pre className="f6 mb0">
                    Error: Button with text &quot;Log In&quot; not found

                    tests/users/login.js
                </pre>
              </div>
            </div>

            <div className="flex justify-between bg-lightest-red bt b--white hover-white hover-bg-red pointer">
              <div className="flex-auto ph2">
                  test users can log out
              </div>
              <div className="bg-red white bl b--white f6 code flex items-center ph2">
                  00:01<span className="o-60">.331</span>
              </div>
            </div>
            <div className="flex justify-between bg-lightest-green bt b--white hover-white hover-bg-green pointer">
              <div className="flex-auto ph2">
                  test users can edit their profile
              </div>
              <div className="bg-green white bl b--white f6 code flex items-center ph2">
                  00:11<span className="o-60">.023</span>
              </div>
            </div>
            <div className="flex justify-between bg-lightest-green bt b--white hover-white hover-bg-green pointer">
              <div className="flex-auto ph2">
                  test users can open the main dashboard
              </div>
              <div className="bg-green white bl b--white f6 code flex items-center ph2">
                  00:02<span className="o-60">.930</span>
              </div>
            </div>
            <div className="flex justify-between bg-lightest-green bt b--white hover-white hover-bg-green pointer">
              <div className="flex-auto ph2">
                  test users can change their names
              </div>
              <div className="bg-green white bl b--white f6 code flex items-center ph2">
                  00:00<span className="o-60">.243</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="mt4 pv3-m mw7 center">
        <h2 className="f3 mb0">How to set it up in 5 minutes?</h2>
        <p className="f4 normal mb4">Follow these simple steps while peaking into Semaphore documentation</p>

        <div className="flex-m">
          <div className="flex-shrink-0 dn db-m nl4 pr4">
            <Icon path="images/ill-curious-girl.svg" alt="curious girl" width="74" height="108"/>
          </div>
          <div className="flex-auto pl2-m">
            <div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">1</div>
                <div className="flex-auto pl3 nt1">
                  <h3 className="f4 mb0">Export XML results</h3>
                  <p className="measure-wide">Install a formatter into your test runner and export the results to a file</p>
                </div>
              </div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">2</div>
                <div className="flex-auto pl3 nt1">
                  <h3 className="f4 mb0">Publish results</h3>
                  <p className="measure-wide">Add <code className="f6 bg-white ph1 br2 ba b--black-20">test-results publish results.xml</code> to all jobs that run tests on Semaphore</p>
                </div>
              </div>
              <div className="flex mb2">
                <div className="bg-dark-gray white b w2 h2 flex-shrink-0 flex items-center justify-center br-100">3</div>
                <div className="flex-auto pl3 nt1">
                  <h3 className="f4 mb0">Merge results from all jobs</h3>
                  <p className="measure-wide">Once your pipeline is finished, merge the results and generate report using <code className="f6 bg-white ph1 br2 ba b--black-20">test-results gen-pipeline-report</code> and you’re done!</p>

                  <div className="mt4">
                    <p className="mb2">Follow the detailed instructions in Semaphore Docs</p>
                    <p className="mb0"><a href="https://docs.semaphoreci.com/essentials/test-summary/#setting-up-test-reports" target="_blank" className="btn btn-secondary" rel="noreferrer">Docs: Setting up Test Reports</a></p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
